# AdGuard VPN CLI Interactive Manager

A Bash script providing an interactive, letter-driven menu for the official AdGuard VPN command-line client (adguardvpn-cli).

## Description

The script presents all functionality of adguardvpn-cli through a simple terminal menu. Actions are selected by entering a single letter. Enhanced interactive flows are included for VPN connection and configuration tasks.

The script performs the following at startup:

- Verifies that adguardvpn-cli is present in PATH.
- Requests administrative privileges once using sudo -v to cache credentials for operations that require them (such as TUN mode connections).
- Does not re-execute itself as root, ensuring that user-specific state (login credentials and the AdGuard VPN data directory) remains associated with the original user account.
- Displays the complete list of available VPN locations in relevant menus without imposing an artificial count limit.
- Applies terminal colors using tput when available for broad compatibility, with fallback to direct ANSI sequences or no color.

## Requirements

- Bash
- adguardvpn-cli installed and executable from PATH
- sudo (required for full operation of privileged commands)

## Installation

1. Install adguardvpn-cli using one of the official installation scripts.
   
   https://adguard-vpn.com/kb/fr/adguard-vpn-for-linux/

2. Copy adguard.sh to a suitable location and set the executable bit:
   
   chmod +x /path/to/adguard.sh

3. Optionally, add the directory containing the script to PATH or define a shell alias for convenience.

## Usage

Execute the script:

   /path/to/adguard.sh

The script first checks for the presence of adguardvpn-cli. It then requests cached sudo credentials and displays the main menu. Enter the letter corresponding to the desired action and press Enter.

After most actions complete, press Enter to return to the menu.

## Main Menu

l - login
    Log in to AdGuard VPN or create a new account.

o - logout
    Log out of the current AdGuard VPN session.

e - list-locations
    Display the full list of available VPN locations, sorted by estimated ping time.

c - connect
    Establish a VPN connection. Additional options are presented for location selection.

d - disconnect
    Terminate the current VPN connection.

s - status
    Show the current status of the VPN service.

i - license
    Display license and subscription details.

f - config
    Open the configuration submenu (see below).

v - check-update
    Check whether a newer version of adguardvpn-cli is available.

x - export-logs
    Export service logs to a zip file.

u - update
    Install a newer version of adguardvpn-cli if one is available.

z - site-exclusions
    Open the site exclusions management submenu (see below).

q - Quit
    Exit the interactive manager.

## Connect Submenu

When connect is selected, the following choices are offered:

1. Connect using the last used location.
2. Connect to the fastest available location.
3. Specify a location manually by name, country, or ISO code.
4. Select a location interactively from the complete list of available locations (presented with numeric indices).
5. Return to the main menu.

Option 4 retrieves the full list of locations from adguardvpn-cli and allows selection by number. All locations are included; no count limit is applied.

## Configuration Submenu

The configuration submenu exposes every configuration command provided by adguardvpn-cli through prompted input:

- set-mode (TUN or SOCKS)
- set-dns
- set-socks-port
- set-socks-host
- set-socks-username
- set-socks-password
- clear-socks-auth
- set-change-system-dns
- set-tun-routing-mode
- create-route-script
- set-crash-reporting
- set-telemetry
- set-update-channel
- set-protocol
- set-post-quantum
- set-show-hints
- set-debug-logging
- set-show-notifications
- set-bound-if-override
- show (display current configuration)

Each setting accepts the values documented by the underlying adguardvpn-cli tool.

## Site Exclusions Submenu

The site-exclusions submenu provides the following operations:

- add: Add one or more exclusions. Multiple entries may be supplied separated by spaces. Supported formats include domain names, wildcard patterns (*.example.com), IP addresses, and CIDR ranges.
- remove: Remove one or more previously added exclusions.
- show: Display the current exclusion list. A specific mode (general or selective) may be specified.
- clear: Remove all exclusions from the active list or from a specified mode.
- mode: Display the current exclusion mode or switch between general and selective modes.

Commands that accept a mode use the --for-mode option when a mode other than the current default is required.

## Notes

All menu actions invoke the real adguardvpn-cli binary. The script supplies only the interactive selection layer; output formatting, error handling, and side effects are determined by adguardvpn-cli.

Administrative credential caching is performed at launch. If a privileged operation is attempted after the cache has expired, adguardvpn-cli may request the password again.

The full set of VPN locations is obtained by calling adguardvpn-cli list-locations with no positional count argument.

Color output is omitted when standard output is not a terminal or when tput is unavailable.

## References

The complete set of commands, options, and configuration parameters is documented by the AdGuard VPN CLI itself and in the official knowledge base.

Run the following command for the built-in reference:

   adguardvpn-cli --help-all

Official documentation is available at:

   https://adguard-vpn.com/kb/adguard-vpn-for-linux/