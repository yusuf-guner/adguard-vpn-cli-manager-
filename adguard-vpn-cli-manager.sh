#!/usr/bin/env bash
#
# AdGuard VPN CLI Interactive Manager (Bash)
#
# Provides a friendly, interactive, letter-driven menu wrapping all
# official adguardvpn-cli commands and subcommands:
#   login, logout, list-locations, connect, disconnect, status,
#   license, config (full submenu), check-update, export-logs,
#   update, site-exclusions (full submenu).
#
# Requests admin rights at launch (via sudo -v) to cache credentials
# for privileged operations (TUN mode, connect, route changes, etc.).
# The script itself does not force a root re-exec so that user-specific
# state (~/.local/share/adguardvpn-cli, logins, etc.) is preserved.
#

set -o pipefail

CLI_CMD="adguardvpn-cli"

# Color setup: prefer tput (portable, correct codes per TERM) for reliable
# color rendering across terminals, tmux, SSH, etc. Fall back to ANSI or no color.
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED=$(tput setaf 1 2>/dev/null || echo '')
  GREEN=$(tput setaf 2 2>/dev/null || echo '')
  YELLOW=$(tput setaf 3 2>/dev/null || echo '')
  BLUE=$(tput setaf 4 2>/dev/null || echo '')
  CYAN=$(tput setaf 6 2>/dev/null || echo '')
  BOLD=$(tput bold 2>/dev/null || echo '')
  NC=$(tput sgr0 2>/dev/null || echo '')
elif [ -t 1 ]; then
  # Fallback to common ANSI escapes when tput is unavailable
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' ; GREEN='' ; YELLOW='' ; BLUE='' ; CYAN='' ; BOLD='' ; NC=''
fi

pause() {
  echo
  read -r -p "Press Enter to continue..." _
  echo
}

print_header() {
  (tput clear || clear || printf '\033c') 2>/dev/null
  echo -e "${BLUE}${BOLD}=============================================="
  echo -e "   AdGuard VPN - Interactive CLI Manager"
  echo -e "==============================================${NC}"
  local ver
  ver=$($CLI_CMD --version 2>/dev/null || echo 'unknown version')
  echo -e "  ${CYAN}Binary: ${CLI_CMD}  |  ${ver}${NC}"
  echo
}

check_cli() {
  if ! command -v "$CLI_CMD" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: '$CLI_CMD' is not installed or not found in PATH.${NC}"
    echo
    echo "To install the Release version:"
    echo '  curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/master/scripts/release/install.sh | sh -s -- -v'
    echo
    echo "Beta version:"
    echo '  curl -fsSL https://raw.githubusercontent.com/AdguardTeam/AdGuardVPNCLI/master/scripts/beta/install.sh | sh -s -- -v'
    echo
    echo "Then relaunch this script."
    exit 1
  fi
}

request_admin_rights() {
  echo -e "${YELLOW}Requesting admin rights at launch...${NC}"
  echo " (Some commands such as connect in TUN mode, config, etc. require them.)"
  echo

  if [ "$(id -u)" -eq 0 ]; then
    echo -e "${GREEN}You are already root.${NC}"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    if sudo -v; then
      echo -e "${GREEN}Admin rights acquired (sudo cache valid for a few minutes).${NC}"
    else
      echo -e "${YELLOW}Warning: sudo -v failed. Some operations may fail or repeatedly prompt for a password.${NC}"
    fi
  else
    echo -e "${YELLOW}Warning: sudo not available. Privileged commands will fail unless you are root.${NC}"
  fi
  echo
}

# ----------------------- COMMAND FUNCTIONS -----------------------

do_login() {
  echo -e "${CYAN}>>> Login (log in or create AdGuard account)${NC}"
  echo "Follow the on-screen instructions: choose 'b' to open the browser link, etc."
  echo
  "$CLI_CMD" login
  pause
}

do_logout() {
  echo -e "${CYAN}>>> Logout${NC}"
  "$CLI_CMD" logout
  pause
}

do_list_locations() {
  echo -e "${CYAN}>>> List available VPN locations${NC}"
  # Show the complete list (sorted by ping), no limit
  "$CLI_CMD" list-locations
  pause
}

do_connect() {
  echo -e "${CYAN}>>> Connect to VPN${NC}"
  echo "Options:"
  echo "  1) Last used location (default)"
  echo "  2) Fastest available (-f --fastest)"
  echo "  3) Specify manually (city, country or ISO code)"
  echo "  4) Pick interactively from the list"
  echo "  5) Back to main menu"
  echo
  read -r -p "Your choice [1-5]: " cch
  cch=${cch:-1}

  case "$cch" in
    1)
      echo "Connecting to last used location..."
      "$CLI_CMD" connect -y
      ;;
    2)
      echo "Connecting to fastest location..."
      "$CLI_CMD" connect -f -y
      ;;
    3)
      read -r -p "Location (e.g. Paris, France, FR, Amsterdam, GB): " loc
      if [ -n "$loc" ]; then
        echo "Connecting to '$loc'..."
        "$CLI_CMD" connect -l "$loc" -y
      fi
      ;;
    4)
      echo "Retrieving full location list..."
      local list_output
      # Strip ANSI color/style codes emitted by the CLI for reliable parsing.
      # No count limit so the complete list of locations is shown.
      list_output=$("$CLI_CMD" list-locations 2>/dev/null | sed -r 's/\x1B\[[0-9;?]*[a-zA-Z]//g')
      local -a loc_lines
      mapfile -t loc_lines < <(echo "$list_output" | sed -n '2,/^You can connect/p' | head -n -1 | sed '/^[[:space:]]*$/d')
      if [ "${#loc_lines[@]}" -eq 0 ]; then
        echo -e "${RED}No locations retrieved.${NC}"
        pause
        return
      fi
      echo
      echo "Available locations (sorted by ping):"
      local i
      for i in "${!loc_lines[@]}"; do
        printf "  %2d) %s\n" $((i+1)) "${loc_lines[$i]}"
      done
      echo
      read -r -p "Location number (0 = cancel): " num
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#loc_lines[@]}" ]; then
        local sel_line="${loc_lines[$((num-1))]}"
        local iso
        iso=$(echo "$sel_line" | awk '{print $1}')
        echo "Connecting to $iso ..."
        "$CLI_CMD" connect -l "$iso" -y
      else
        echo "Selection cancelled."
      fi
      ;;
    *)
      echo "Back."
      ;;
  esac
  pause
}

do_disconnect() {
  echo -e "${CYAN}>>> Disconnect VPN${NC}"
  "$CLI_CMD" disconnect
  pause
}

do_status() {
  echo -e "${CYAN}>>> Current VPN service status${NC}"
  "$CLI_CMD" status
  pause
}

do_license() {
  echo -e "${CYAN}>>> License / subscription information${NC}"
  "$CLI_CMD" license
  pause
}

do_check_update() {
  echo -e "${CYAN}>>> Check for updates${NC}"
  "$CLI_CMD" check-update
  pause
}

do_export_logs() {
  echo -e "${CYAN}>>> Export logs to zip${NC}"
  local default_name="adguardvpn_logs_$(date +%Y%m%d-%H%M%S).zip"
  read -r -p "Output path (file or directory) [default: $default_name]: " out
  out=${out:-$default_name}
  read -r -p "Force overwrite if the artifact exists? (y/N): " force
  echo
  if [[ "$force" =~ ^[yY] ]]; then
    "$CLI_CMD" export-logs -o "$out" -f
  else
    "$CLI_CMD" export-logs -o "$out"
  fi
  pause
}

do_update() {
  echo -e "${YELLOW}>>> Install new version if available${NC}"
  echo "This operation will download and replace the current version."
  read -r -p "Continue? (y/N): " yn
  if [[ "$yn" =~ ^[yY] ]]; then
    "$CLI_CMD" update -y
  else
    echo "Cancelled."
  fi
  pause
}

# ----------------------- CONFIG SUBMENU -----------------------

do_config_menu() {
  while true; do
    print_header
    echo -e "${BOLD}--- VPN Configuration (config) ---${NC}"
    echo
    echo "  m  - set-mode (TUN or SOCKS)"
    echo "  n  - set-dns (DNS upstream server)"
    echo "  p  - set-socks-port"
    echo "  h  - set-socks-host"
    echo "  u  - set-socks-username"
    echo "  w  - set-socks-password"
    echo "  a  - clear-socks-auth"
    echo "  y  - set-change-system-dns (on/off)"
    echo "  r  - set-tun-routing-mode (auto / none / script)"
    echo "  s  - create-route-script"
    echo "  c  - set-crash-reporting (on/off)"
    echo "  t  - set-telemetry (on/off)"
    echo "  k  - set-update-channel (release / beta / nightly)"
    echo "  o  - set-protocol (auto / http2 / quic)"
    echo "  q  - set-post-quantum (on/off)"
    echo "  i  - set-show-hints (on/off)"
    echo "  b  - set-debug-logging (on/off)"
    echo "  f  - set-show-notifications (on/off)"
    echo "  d  - set-bound-if-override (interface name or '' to disable)"
    echo "  v  - show (display current configuration)"
    echo
    echo "  x  - Back to main menu"
    echo
    read -r -p "Your choice (letter): " ch
    ch=$(echo "$ch" | tr '[:upper:]' '[:lower:]')

    case "$ch" in
      m)
        read -r -p "VPN mode (tun or socks): " val
        [ -n "$val" ] && "$CLI_CMD" config set-mode "$val"
        ;;
      n)
        read -r -p "DNS upstream (address or 'default'): " val
        [ -n "$val" ] && "$CLI_CMD" config set-dns "$val"
        ;;
      p)
        read -r -p "SOCKS port (e.g. 1080): " val
        [ -n "$val" ] && "$CLI_CMD" config set-socks-port "$val"
        ;;
      h)
        read -r -p "SOCKS host (e.g. 127.0.0.1): " val
        [ -n "$val" ] && "$CLI_CMD" config set-socks-host "$val"
        ;;
      u)
        read -r -p "SOCKS username: " val
        [ -n "$val" ] && "$CLI_CMD" config set-socks-username "$val"
        ;;
      w)
        read -r -s -p "SOCKS password: " val; echo
        [ -n "$val" ] && "$CLI_CMD" config set-socks-password "$val"
        ;;
      a)
        "$CLI_CMD" config clear-socks-auth
        ;;
      y)
        read -r -p "Change system DNS? (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-change-system-dns "$val"
        ;;
      r)
        read -r -p "TUN routing mode (auto/none/script): " val
        [ -n "$val" ] && "$CLI_CMD" config set-tun-routing-mode "$val"
        ;;
      s)
        "$CLI_CMD" config create-route-script
        ;;
      c)
        read -r -p "Crash reporting (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-crash-reporting "$val"
        ;;
      t)
        read -r -p "Telemetry / anonymized usage data (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-telemetry "$val"
        ;;
      k)
        read -r -p "Update channel (release/beta/nightly): " val
        [ -n "$val" ] && "$CLI_CMD" config set-update-channel "$val"
        ;;
      o)
        read -r -p "Protocol (auto/http2/quic): " val
        [ -n "$val" ] && "$CLI_CMD" config set-protocol "$val"
        ;;
      q)
        read -r -p "Post-quantum cryptography (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-post-quantum "$val"
        ;;
      i)
        read -r -p "Show hints (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-show-hints "$val"
        ;;
      b)
        read -r -p "Debug logging (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-debug-logging "$val"
        ;;
      f)
        read -r -p "System notifications (on/off): " val
        [ -n "$val" ] && "$CLI_CMD" config set-show-notifications "$val"
        ;;
      d)
        read -r -p "Outbound interface override (name or empty to disable): " val
        "$CLI_CMD" config set-bound-if-override "$val"
        ;;
      v)
        "$CLI_CMD" config show
        ;;
      x)
        return
        ;;
      *)
        echo -e "${RED}Invalid choice.${NC}"
        sleep 0.7
        ;;
    esac
    [ "$ch" != "x" ] && pause
  done
}

# ----------------------- SITE EXCLUSIONS SUBMENU -----------------------

do_exclusions_menu() {
  while true; do
    print_header
    echo -e "${BOLD}--- Site Exclusions (site-exclusions) ---${NC}"
    echo
    "$CLI_CMD" site-exclusions mode 2>/dev/null || true
    echo
    echo "  a  - add : Add one or more exclusions"
    echo "  r  - remove : Remove one or more exclusions"
    echo "  s  - show : Show current exclusion list"
    echo "  c  - clear : Clear all exclusions (current or specified mode)"
    echo "  m  - mode : Set or show exclusion mode (general / selective)"
    echo
    echo "  x  - Back to main menu"
    echo
    read -r -p "Your choice (letter): " ch
    ch=$(echo "$ch" | tr '[:upper:]' '[:lower:]')

    case "$ch" in
      a)
        echo "Enter exclusions (domains, *.ex.com, IPs, CIDR) separated by spaces:"
        read -r -a arr
        if [ "${#arr[@]}" -gt 0 ]; then
          "$CLI_CMD" site-exclusions add "${arr[@]}"
        fi
        ;;
      r)
        echo "Enter exclusions to remove (separated by spaces):"
        read -r -a arr
        if [ "${#arr[@]}" -gt 0 ]; then
          "$CLI_CMD" site-exclusions remove "${arr[@]}"
        fi
        ;;
      s)
        read -r -p "Specific mode (general/selective or empty = current)? " md
        if [ -n "$md" ]; then
          "$CLI_CMD" site-exclusions show --for-mode "$md"
        else
          "$CLI_CMD" site-exclusions show
        fi
        ;;
      c)
        read -r -p "Clear for a specific mode (general/selective or empty = current)? " md
        if [ -n "$md" ]; then
          "$CLI_CMD" site-exclusions clear --for-mode "$md"
        else
          "$CLI_CMD" site-exclusions clear
        fi
        ;;
      m)
        read -r -p "Mode (general or selective, empty = show current): " md
        if [ -n "$md" ]; then
          "$CLI_CMD" site-exclusions mode "$md"
        else
          "$CLI_CMD" site-exclusions mode
        fi
        ;;
      x)
        return
        ;;
      *)
        echo -e "${RED}Invalid choice.${NC}"
        sleep 0.7
        ;;
    esac
    [ "$ch" != "x" ] && pause
  done
}

# ----------------------- MAIN LOOP -----------------------

main_menu() {
  while true; do
    print_header
    echo "Choose an action (enter the letter):"
    echo
    echo "  ${BOLD}l${NC} - login            Log in / create AdGuard VPN account"
    echo "  ${BOLD}o${NC} - logout           Log out from AdGuard VPN"
    echo "  ${BOLD}e${NC} - list-locations   List available VPN locations"
    echo "  ${BOLD}c${NC} - connect          Connect to VPN (last/fastest/specific)"
    echo "  ${BOLD}d${NC} - disconnect       Stop the VPN service"
    echo "  ${BOLD}s${NC} - status           Display current VPN service status"
    echo "  ${BOLD}i${NC} - license          Show license / subscription information"
    echo "  ${BOLD}f${NC} - config           Configure the VPN service (full submenu)"
    echo "  ${BOLD}v${NC} - check-update     Check for updates"
    echo "  ${BOLD}x${NC} - export-logs      Export logs to a zip file"
    echo "  ${BOLD}u${NC} - update           Install new version if available"
    echo "  ${BOLD}z${NC} - site-exclusions  Manage site exclusions (full submenu)"
    echo
    echo "  ${BOLD}q${NC} - Quit"
    echo
    read -r -p "Choice: " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    case "$choice" in
      l) do_login ;;
      o) do_logout ;;
      e) do_list_locations ;;
      c) do_connect ;;
      d) do_disconnect ;;
      s) do_status ;;
      i) do_license ;;
      f) do_config_menu ;;
      v) do_check_update ;;
      x) do_export_logs ;;
      u) do_update ;;
      z) do_exclusions_menu ;;
      q)
        echo -e "${GREEN}Goodbye!${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid choice. Please try again.${NC}"
        sleep 0.8
        ;;
    esac
  done
}

# ----------------------- ENTRY POINT -----------------------

main() {
  check_cli
  request_admin_rights
  main_menu
}

main "$@"
