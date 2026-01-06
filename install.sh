#!/usr/bin/env bash

#
#    app_rpt__ultra :: the ultimate controller experience for app_rpt
#    Copyright (C) 2025   John D. Lewis (AI3I)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

set -euo pipefail

# ==============================================================================
#    install.sh - Installer for app_rpt__ultra
# ==============================================================================
#
#    Usage: sudo ./install.sh [OPTIONS]
#
#    Options:
#        -d, --dest DIR      Installation directory (default: /opt/app_rpt)
#        -n, --node NODE     AllStarLink node number
#        -c, --call CALL     Callsign
#        -z, --zone ZONE     NWS weather zone (e.g., PAC001)
#        -y, --yes           Non-interactive mode (skip confirmations)
#        -h, --help          Show this help message
#
#    Examples:
#        sudo ./install.sh
#        sudo ./install.sh -n 1999 -c W1AW
#        sudo ./install.sh -d /usr/local/app_rpt -n 1999 -c W1AW -z PAC001
#

# ------------------------------------------------------------------------------
#    Configuration
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_APP_RPT="$SCRIPT_DIR/app_rpt"
SOURCE_ASTERISK="$SCRIPT_DIR/asterisk"

# Defaults
DEST_DIR="/opt/app_rpt"
OWNER_USER="asterisk"
OWNER_GROUP="asterisk"
NODE_NUMBER=""
CALLSIGN=""
NWS_ZONE=""
WU_APIKEY=""
WU_STATION=""
LAN_DEVICE=""
WLAN_DEVICE=""
VPN_DEVICE=""
NON_INTERACTIVE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
#    Output Functions
# ------------------------------------------------------------------------------

print_banner() {
    echo -e "${BLUE}"
    cat << 'EOF'
================================================================================
                           _                _           _ _
   __ _ _ __  _ __    _ __| |_     _   _| | |_ _ __ __ _
  / _` | '_ \| '_ \  | '__| '_ \ | | | | | __| '__/ _` |
 | (_| | |_) | |_) | | |  | |_) || |_| | | |_| | | (_| |
  \__,_| .__/| .__/  |_|  | .__/  \__,_|_|\__|_|  \__,_|
       |_|   |_|          |_|

    The Ultimate Controller Experience for Asterisk AllStarLink
================================================================================
EOF
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}[OK]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_step() { echo -e "\n${CYAN}==> $*${NC}"; }

usage() {
    sed -n '24,37p' "$0" | sed 's/^#//'
    exit 0
}

# ------------------------------------------------------------------------------
#    Validation Functions
# ------------------------------------------------------------------------------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_asl3() {
    if ! command -v asterisk &>/dev/null; then
        print_error "Asterisk not found. Is AllStarLink 3 installed?"
        exit 1
    fi
    print_success "Asterisk found"
}

validate_node() {
    local node="$1"
    if [[ ! "$node" =~ ^[0-9]+$ ]]; then
        print_error "Invalid node number: $node (must be numeric)"
        return 1
    fi
    if [[ ${#node} -lt 4 || ${#node} -gt 6 ]]; then
        print_error "Invalid node number: $node (must be 4-6 digits)"
        return 1
    fi
    return 0
}

validate_callsign() {
    local call="$1"
    # Basic callsign validation (letters and numbers, 3-7 chars)
    if [[ ! "$call" =~ ^[A-Za-z0-9]{3,7}$ ]]; then
        print_error "Invalid callsign: $call"
        return 1
    fi
    return 0
}

validate_nws_zone() {
    local zone="$1"
    # NWS zone format: 3 letters + 3 digits (e.g., PAC001)
    if [[ ! "$zone" =~ ^[A-Za-z]{3}[0-9]{3}$ ]]; then
        print_error "Invalid NWS zone: $zone (format: XXX000, e.g., PAC001)"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
#    Network Interface Detection
# ------------------------------------------------------------------------------

detect_network_interfaces() {
    # Detect LAN interface (first non-loopback, non-wireless, non-virtual interface)
    LAN_DEVICE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | \
        grep -v '^wlan' | grep -v '^wl' | grep -v '^tun' | grep -v '^tap' | \
        grep -v '^docker' | grep -v '^br-' | grep -v '^veth' | head -1)
    LAN_DEVICE="${LAN_DEVICE:-eth0}"

    # Detect WLAN interface (first wireless interface)
    WLAN_DEVICE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    if [[ -z "$WLAN_DEVICE" ]]; then
        WLAN_DEVICE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^wlan|^wl' | head -1)
    fi
    WLAN_DEVICE="${WLAN_DEVICE:-wlan0}"

    # Detect VPN interface (first tun/tap interface, or default)
    VPN_DEVICE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^tun|^tap' | head -1)
    VPN_DEVICE="${VPN_DEVICE:-tun0}"
}

# ------------------------------------------------------------------------------
#    Interactive Prompts
# ------------------------------------------------------------------------------

prompt_value() {
    local prompt="$1"
    local default="${2:-}"
    local value=""

    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " value
        echo "${value:-$default}"
    else
        read -rp "$prompt: " value
        echo "$value"
    fi
}

prompt_required() {
    local prompt="$1"
    local validator="${2:-}"
    local value=""

    while true; do
        read -rp "$prompt: " value
        if [[ -z "$value" ]]; then
            print_error "This field is required"
            continue
        fi
        if [[ -n "$validator" ]] && ! $validator "$value"; then
            continue
        fi
        echo "$value"
        return
    done
}

prompt_optional() {
    local prompt="$1"
    local default="${2:-}"
    local validator="${3:-}"
    local value=""

    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " value
        value="${value:-$default}"
    else
        read -rp "$prompt (press Enter to skip): " value
    fi

    if [[ -n "$value" && -n "$validator" ]]; then
        if ! $validator "$value"; then
            echo ""
            return
        fi
    fi
    echo "$value"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        read -rp "$prompt [y/N]: " response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

gather_configuration() {
    print_step "Configuration"
    echo ""
    echo "Please provide the following information for your installation."
    echo "Required fields are marked with *"
    echo ""

    # Node number (required)
    if [[ -z "$NODE_NUMBER" ]]; then
        NODE_NUMBER=$(prompt_required "* AllStarLink Node Number" validate_node)
    fi

    # Callsign (required)
    if [[ -z "$CALLSIGN" ]]; then
        CALLSIGN=$(prompt_required "* Callsign" validate_callsign)
    fi
    CALLSIGN="${CALLSIGN^^}"  # Convert to uppercase

    # NWS Zone (optional but recommended)
    if [[ -z "$NWS_ZONE" ]]; then
        echo ""
        echo "NWS Zone is used for weather alerts. Find yours at:"
        echo "  https://www.weather.gov/gis/publiczones"
        NWS_ZONE=$(prompt_optional "  NWS Zone (e.g., PAC001)" "" validate_nws_zone)
    fi

    # Weather Underground (optional)
    echo ""
    if prompt_yes_no "Configure Weather Underground for weather reporting?"; then
        echo "  Get your API key at: https://www.wunderground.com/member/api-keys"
        WU_APIKEY=$(prompt_optional "  Weather Underground API Key")
        if [[ -n "$WU_APIKEY" ]]; then
            WU_STATION=$(prompt_optional "  Weather Underground Station ID")
        fi
    fi

    # Installation directory
    echo ""
    DEST_DIR=$(prompt_value "Installation directory" "$DEST_DIR")
}

confirm_configuration() {
    echo ""
    print_step "Configuration Summary"
    echo ""
    echo "  Installation directory: $DEST_DIR"
    echo "  Node number:            $NODE_NUMBER"
    echo "  Callsign:               $CALLSIGN"
    echo "  NWS Zone:               ${NWS_ZONE:-<not configured>}"
    echo "  Weather Underground:    ${WU_APIKEY:+configured}${WU_APIKEY:-<not configured>}"
    echo "  Network interfaces:     LAN=$LAN_DEVICE, WLAN=$WLAN_DEVICE, VPN=$VPN_DEVICE"
    echo ""

    if [[ "$NON_INTERACTIVE" != true ]]; then
        if ! prompt_yes_no "Proceed with installation?"; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi
}

# ------------------------------------------------------------------------------
#    Installation Functions
# ------------------------------------------------------------------------------

install_dependencies() {
    print_step "Installing Dependencies"

    if command -v apt-get &>/dev/null; then
        if ! command -v jq &>/dev/null; then
            print_info "Installing jq..."
            apt-get update -qq
            apt-get install -y -qq jq
            print_success "jq installed"
        else
            print_success "jq already installed"
        fi
    else
        if ! command -v jq &>/dev/null; then
            print_warning "Please install 'jq' manually for your distribution"
        fi
    fi
}

configure_asterisk_user() {
    print_step "Configuring Asterisk User"

    # Check if asterisk user exists
    if ! id "$OWNER_USER" &>/dev/null; then
        print_error "User '$OWNER_USER' does not exist"
        print_info "AllStarLink 3 should have created this user"
        exit 1
    fi

    # Add asterisk to required groups
    local groups_to_add="sudo,dialout,audio,plugdev"
    print_info "Adding $OWNER_USER to groups: $groups_to_add"
    usermod -aG "$groups_to_add" "$OWNER_USER" || true

    # Set bash shell
    if [[ $(getent passwd "$OWNER_USER" | cut -d: -f7) != "/bin/bash" ]]; then
        print_info "Setting bash shell for $OWNER_USER"
        usermod -s /bin/bash "$OWNER_USER"
    fi

    print_success "Asterisk user configured"
}

configure_sudoers() {
    print_step "Configuring Sudo Access"

    local sudoers_file="/etc/sudoers.d/app_rpt_ultra"

    if [[ -f "$sudoers_file" ]]; then
        print_success "Sudoers configuration already exists"
        return
    fi

    print_info "Creating sudoers configuration..."
    cat > "$sudoers_file" << 'EOF'
# app_rpt__ultra - Allow asterisk user to run commands without password
asterisk ALL=(ALL:ALL) NOPASSWD: ALL
EOF
    chmod 440 "$sudoers_file"

    # Validate sudoers file
    if visudo -c -f "$sudoers_file" &>/dev/null; then
        print_success "Sudoers configured"
    else
        print_error "Invalid sudoers configuration"
        rm -f "$sudoers_file"
        exit 1
    fi
}

create_directories() {
    print_step "Creating Directory Structure"

    mkdir -p "$DEST_DIR"/{bin,lib,util,sounds,backups}
    mkdir -p "$DEST_DIR"/sounds/{ids,rpt,tails,wx,letters,digits,custom}
    mkdir -p "$DEST_DIR"/sounds/{_male,_female,_sndfx}
    mkdir -p /opt/asterisk
    mkdir -p /etc/asterisk/custom

    print_success "Directories created"
}

setup_sound_symlinks() {
    print_step "Setting Up Sound Symlinks"

    # Remove conflicting Asterisk en directory if it exists
    if [[ -d "/var/lib/asterisk/sounds/en" ]]; then
        print_info "Removing conflicting Asterisk en directory"
        rm -rf /var/lib/asterisk/sounds/en
        print_success "Removed /var/lib/asterisk/sounds/en (conflicts with app_rpt__ultra vocabulary)"
    fi

    # Remove existing sound directories (they'll be replaced with symlinks)
    local sound_dirs=("/var/lib/asterisk/sounds" "/usr/share/asterisk/sounds")

    for dir in "${sound_dirs[@]}"; do
        if [[ -L "$dir" ]]; then
            print_info "Symlink already exists: $dir"
        elif [[ -d "$dir" ]]; then
            print_info "Removing existing directory: $dir"
            rm -rf "$dir"
            ln -s "$DEST_DIR/sounds" "$dir"
            print_success "Created symlink: $dir -> $DEST_DIR/sounds"
        else
            mkdir -p "$(dirname "$dir")"
            ln -s "$DEST_DIR/sounds" "$dir"
            print_success "Created symlink: $dir -> $DEST_DIR/sounds"
        fi
    done

    # Also check for en directory in destination sounds directory
    if [[ -d "$DEST_DIR/sounds/en" ]]; then
        print_info "Removing conflicting en directory from $DEST_DIR/sounds"
        rm -rf "$DEST_DIR/sounds/en"
        print_success "Removed en directory (conflicts with app_rpt__ultra vocabulary)"
    fi
}

install_scripts() {
    print_step "Installing Scripts"

    cp -r "$SOURCE_APP_RPT/bin/"* "$DEST_DIR/bin/"

    # Replace %%BASEDIR%% placeholder
    find "$DEST_DIR/bin" -name "*.sh" -type f -exec \
        sed -i "s|%%BASEDIR%%|$DEST_DIR|g" {} \;

    chmod +x "$DEST_DIR/bin/"*.sh

    print_success "Scripts installed"
}

install_utils() {
    print_step "Installing Utility Scripts"

    # Copy utility scripts from repo root to /opt/app_rpt/util/
    local util_scripts=("install.sh" "upgrade.sh" "repair.sh" "uninstall.sh")

    for script in "${util_scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            cp "$SCRIPT_DIR/$script" "$DEST_DIR/util/"
        else
            print_warning "Utility script not found: $script"
        fi
    done

    # Replace %%BASEDIR%% placeholder in util scripts (if any)
    find "$DEST_DIR/util" -name "*.sh" -type f -exec \
        sed -i "s|%%BASEDIR%%|$DEST_DIR|g" {} \;

    chmod +x "$DEST_DIR/util/"*.sh
    print_success "Utility scripts installed (install.sh, upgrade.sh, repair.sh, uninstall.sh)"
}

install_sounds() {
    print_step "Installing Sound Files"

    if [[ -d "$SOURCE_APP_RPT/sounds" ]]; then
        cp -r "$SOURCE_APP_RPT/sounds/"* "$DEST_DIR/sounds/" 2>/dev/null || true
        print_success "Sound files installed"
    else
        print_warning "No sound files found in source directory"
    fi
}

install_lib_files() {
    print_step "Installing Library Files"

    if [[ -d "$SOURCE_APP_RPT/lib" ]]; then
        cp -r "$SOURCE_APP_RPT/lib/"* "$DEST_DIR/lib/" 2>/dev/null || true
        print_success "Library files installed"
    fi
}

install_config() {
    print_step "Installing Configuration"

    local config_file="$DEST_DIR/config.ini"

    if [[ -f "$config_file" ]]; then
        print_warning "config.ini exists, backing up..."
        cp "$config_file" "${config_file}.bkp.$(date +%Y%m%d%H%M%S)"
    fi

    cp "$SOURCE_APP_RPT/config.ini" "$config_file"

    # Update paths
    sed -i "s|/opt/app_rpt|$DEST_DIR|g" "$config_file"

    # Update node number
    sed -i "s|MYNODE=%MYNODE%|MYNODE=$NODE_NUMBER|g" "$config_file"
    sed -i "s|MYNODE=.*|MYNODE=$NODE_NUMBER|" "$config_file"

    # Update NWS zone
    if [[ -n "$NWS_ZONE" ]]; then
        sed -i "s|NWSZONE=XXX000|NWSZONE=$NWS_ZONE|g" "$config_file"
    fi

    # Update Weather Underground settings
    if [[ -n "$WU_APIKEY" ]]; then
        sed -i "s|WUAPIKEY=empty|WUAPIKEY=$WU_APIKEY|g" "$config_file"
    fi
    if [[ -n "$WU_STATION" ]]; then
        sed -i "s|WUSTATION=empty|WUSTATION=$WU_STATION|g" "$config_file"
    fi

    # Update network interface settings
    if [[ -n "$LAN_DEVICE" ]]; then
        sed -i "s|landevice=eth0|landevice=$LAN_DEVICE|g" "$config_file"
    fi
    if [[ -n "$WLAN_DEVICE" ]]; then
        sed -i "s|wlandevice=wlan0|wlandevice=$WLAN_DEVICE|g" "$config_file"
    fi
    if [[ -n "$VPN_DEVICE" ]]; then
        sed -i "s|vpndevice=tun0|vpndevice=$VPN_DEVICE|g" "$config_file"
    fi

    print_success "Configuration installed"
}

install_asterisk_configs() {
    print_step "Installing Asterisk Configuration"

    local asterisk_dir="/etc/asterisk"

    # Install rpt.conf template
    if [[ -f "$SOURCE_ASTERISK/rpt.conf" ]]; then
        local rpt_dest="$asterisk_dir/rpt.conf"
        if [[ -f "$rpt_dest" ]]; then
            print_warning "rpt.conf exists, saving template as rpt.conf.app_rpt_ultra"
            cp "$SOURCE_ASTERISK/rpt.conf" "$rpt_dest.app_rpt_ultra"
        else
            cp "$SOURCE_ASTERISK/rpt.conf" "$rpt_dest"
        fi

        # Update placeholders in rpt.conf
        local target="$rpt_dest"
        [[ -f "$rpt_dest.app_rpt_ultra" ]] && target="$rpt_dest.app_rpt_ultra"

        sed -i "s|%MYNODE%|$NODE_NUMBER|g" "$target"
        sed -i "s|%MYCALL%|$CALLSIGN|g" "$target"
        sed -i "s|/opt/app_rpt|$DEST_DIR|g" "$target"
    fi

    # Install extensions_custom.conf
    if [[ -f "$SOURCE_ASTERISK/extensions_custom.conf" ]]; then
        cp "$SOURCE_ASTERISK/extensions_custom.conf" "$asterisk_dir/custom/extensions.conf"
        sed -i "s|/opt/app_rpt|$DEST_DIR|g" "$asterisk_dir/custom/extensions.conf"
    fi

    print_success "Asterisk configuration installed"
}

generate_voice_id() {
    print_step "Generating Temporary Voice ID"

    local voice_id_file="$DEST_DIR/sounds/voice_id.ulaw"
    local male_dir="$DEST_DIR/sounds/_male"

    if [[ ! -d "$male_dir" ]]; then
        print_warning "Male voice directory not found, skipping voice ID generation"
        return
    fi

    # Build voice ID from callsign: "THIS IS <callsign> REPEATER"
    local files=("$male_dir/this_is.ulaw")

    # Add each character of the callsign
    for (( i=0; i<${#CALLSIGN}; i++ )); do
        local char="${CALLSIGN:$i:1}"
        char="${char,,}"  # lowercase
        local char_file="$male_dir/${char}.ulaw"
        if [[ -f "$char_file" ]]; then
            files+=("$char_file")
        fi
    done

    files+=("$male_dir/repeater.ulaw")

    # Concatenate files
    local valid_files=()
    for f in "${files[@]}"; do
        [[ -f "$f" ]] && valid_files+=("$f")
    done

    if [[ ${#valid_files[@]} -gt 0 ]]; then
        cat "${valid_files[@]}" > "$voice_id_file"
        print_success "Generated voice ID: THIS IS $CALLSIGN REPEATER"
    else
        print_warning "Could not generate voice ID (missing sound files)"
    fi
}

install_crontab() {
    print_step "Installing Crontab"

    local crontab_file
    crontab_file=$(mktemp)

    # Get existing crontab
    crontab -u "$OWNER_USER" -l > "$crontab_file" 2>/dev/null || true

    # Check if already installed
    if grep -q "app_rpt__ultra" "$crontab_file" 2>/dev/null; then
        print_warning "Crontab entries already exist"
        rm -f "$crontab_file"
        return
    fi

    cat >> "$crontab_file" << EOF

# ==============================================================================
# app_rpt__ultra cron jobs
# ==============================================================================
* * * * *      $DEST_DIR/bin/idkeeper.sh        >/dev/null 2>&1
* * * * *      $DEST_DIR/bin/tailkeeper.sh      >/dev/null 2>&1
* * * * *      $DEST_DIR/bin/timekeeper.sh      >/dev/null 2>&1
* * * * *      $DEST_DIR/bin/weatheralert.sh    >/dev/null 2>&1
*/15 * * * *   $DEST_DIR/bin/weatherkeeper.sh   >/dev/null 2>&1
0 0 * * *      $DEST_DIR/bin/datekeeper.sh      >/dev/null 2>&1
0 0 * * *      $DEST_DIR/bin/datadumper.sh      >/dev/null 2>&1
EOF

    crontab -u "$OWNER_USER" "$crontab_file"
    rm -f "$crontab_file"

    print_success "Crontab installed"
}

set_permissions() {
    print_step "Setting Permissions"

    chown -R "$OWNER_USER:$OWNER_GROUP" "$DEST_DIR"
    chown -R "$OWNER_USER:$OWNER_GROUP" /opt/asterisk
    chown -R "$OWNER_USER:$OWNER_GROUP" /etc/asterisk
    chmod 755 "$DEST_DIR"
    chmod 644 "$DEST_DIR/config.ini"
    chmod 755 "$DEST_DIR/bin/"*.sh

    # Create log file
    touch /var/log/app_rpt.log
    chown "$OWNER_USER:$OWNER_GROUP" /var/log/app_rpt.log

    print_success "Permissions set"
}

run_initial_setup() {
    print_step "Running Initial Setup"

    # Generate today's date
    print_info "Generating current date announcement..."
    sudo -u "$OWNER_USER" "$DEST_DIR/bin/datekeeper.sh" 2>/dev/null || true

    print_success "Initial setup complete"
}

print_summary() {
    echo ""
    echo -e "${GREEN}================================================================================"
    echo "                        Installation Complete!"
    echo "================================================================================${NC}"
    echo ""
    echo "  Installation directory: $DEST_DIR"
    echo "  Node number:            $NODE_NUMBER"
    echo "  Callsign:               $CALLSIGN"
    echo "  Log file:               /var/log/app_rpt.log"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    echo "  1. Review and customize your configuration:"
    echo "     ${CYAN}$DEST_DIR/config.ini${NC}"
    echo ""
    if [[ -f "/etc/asterisk/rpt.conf.app_rpt_ultra" ]]; then
        echo "  2. Review the rpt.conf template and merge with your existing config:"
        echo "     ${CYAN}/etc/asterisk/rpt.conf.app_rpt_ultra${NC}"
        echo ""
    fi
    echo "  3. Restart Asterisk to apply changes:"
    echo "     ${CYAN}sudo systemctl restart asterisk${NC}"
    echo ""
    echo "  4. Test your voice ID:"
    echo "     ${CYAN}sudo asterisk -rx \"rpt localplay $NODE_NUMBER voice_id\"${NC}"
    echo ""
    echo -e "${BLUE}Documentation:${NC} See README.md for detailed operation instructions"
    echo ""
}

# ------------------------------------------------------------------------------
#    Main
# ------------------------------------------------------------------------------

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dest)
                DEST_DIR="$2"
                shift 2
                ;;
            -n|--node)
                NODE_NUMBER="$2"
                shift 2
                ;;
            -c|--call)
                CALLSIGN="$2"
                shift 2
                ;;
            -z|--zone)
                NWS_ZONE="$2"
                shift 2
                ;;
            -y|--yes)
                NON_INTERACTIVE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    print_banner

    # Pre-flight checks
    check_root
    check_asl3

    # Gather configuration interactively if not provided
    if [[ -z "$NODE_NUMBER" || -z "$CALLSIGN" ]]; then
        if [[ "$NON_INTERACTIVE" == true ]]; then
            print_error "Node number (-n) and callsign (-c) required in non-interactive mode"
            exit 1
        fi
        gather_configuration
    fi

    # Validate provided values
    validate_node "$NODE_NUMBER" || exit 1
    validate_callsign "$CALLSIGN" || exit 1
    [[ -n "$NWS_ZONE" ]] && { validate_nws_zone "$NWS_ZONE" || NWS_ZONE=""; }

    CALLSIGN="${CALLSIGN^^}"

    # Detect network interfaces
    print_step "Detecting Network Interfaces"
    detect_network_interfaces
    print_info "LAN:  $LAN_DEVICE"
    print_info "WLAN: $WLAN_DEVICE"
    print_info "VPN:  $VPN_DEVICE"

    confirm_configuration

    # Run installation
    install_dependencies
    configure_asterisk_user
    configure_sudoers
    create_directories
    setup_sound_symlinks
    install_scripts
    install_utils
    install_sounds
    install_lib_files
    install_config
    install_asterisk_configs
    generate_voice_id
    install_crontab
    set_permissions
    run_initial_setup

    print_summary
}

main "$@"
