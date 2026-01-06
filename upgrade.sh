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
#    upgrade.sh - Safe upgrade tool for app_rpt__ultra
# ==============================================================================
#
#    This script safely upgrades an existing app_rpt__ultra installation to
#    the latest version, handling configuration migration, script updates,
#    and validation with automatic rollback on failure.
#

# Version information
readonly SCRIPT_VERSION="2.0.1"
readonly SCRIPT_NAME="upgrade.sh"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation paths
readonly INSTALL_BASE="/opt/app_rpt"
readonly CONFIG_FILE="$INSTALL_BASE/config.ini"
readonly VERSION_FILE="$INSTALL_BASE/VERSION"
readonly BACKUP_BASE="$INSTALL_BASE/backups"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ==============================================================================
#    Logging Functions
# ==============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $*" >&2
}

log_success() {
    echo -e "${CYAN}[✓]${NC} $*" >&2
}

# ==============================================================================
#    Help Text
# ==============================================================================

show_help() {
    cat <<'EOF'
app_rpt__ultra Upgrade Tool

Usage: sudo ./upgrade.sh [options]

Options:
  --dry-run          Show what would change without making changes
  --force            Skip version check, force upgrade even if same version
  --no-backup        Skip backup creation (NOT RECOMMENDED)
  --auto-yes         Assume yes to all prompts (dangerous!)
  --help             Show this help message

Examples:
  sudo ./upgrade.sh                    # Interactive upgrade with prompts
  sudo ./upgrade.sh --dry-run          # Preview changes without applying
  sudo ./upgrade.sh --force            # Force upgrade/reinstall

Description:
  This script safely upgrades an existing app_rpt__ultra installation to
  the latest version. It will:

  1. Create a backup of your current installation
  2. Migrate your config.ini (preserving all your settings)
  3. Install the new common.sh library
  4. Update all 21+ scripts
  5. Validate the installation
  6. Update the version file

  If any step fails, it will automatically rollback to the backup.

Exit Codes:
  0 - Upgrade successful
  1 - Pre-flight checks failed or user cancelled
  2 - Backup failed
  3 - Config migration failed
  4 - Script installation failed
  5 - Validation failed (rollback triggered)

EOF
}

# ==============================================================================
#    Pre-flight Checks
# ==============================================================================

check_prerequisites() {
    log_step "Running pre-flight checks..."

    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi

    # Check if installation exists
    if [[ ! -d "$INSTALL_BASE" ]]; then
        log_error "Installation not found at $INSTALL_BASE"
        log_error "Please run install.sh first"
        exit 1
    fi

    # Check config.ini exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_error "Installation appears incomplete"
        exit 1
    fi

    # Check if asterisk user exists
    if ! id asterisk &>/dev/null; then
        log_error "asterisk user not found"
        log_error "Please ensure Asterisk/ASL3 is installed"
        exit 1
    fi

    # Check required commands
    local missing_cmds=()
    for cmd in jq rsync awk sed grep; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi

    # Check Asterisk is installed (optional, might be in custom path)
    if ! command -v asterisk &>/dev/null; then
        log_warn "asterisk command not found in PATH"
        log_warn "Will continue but Asterisk integration may fail"
    fi

    log_success "Pre-flight checks passed"
}

# ==============================================================================
#    Version Management
# ==============================================================================

get_installed_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

get_repo_version() {
    if [[ -f "$REPO_DIR/VERSION" ]]; then
        cat "$REPO_DIR/VERSION"
    else
        echo "$SCRIPT_VERSION"
    fi
}

compare_versions() {
    local current="$1"
    local new="$2"

    # If current is unknown, always upgrade
    if [[ "$current" == "unknown" ]]; then
        return 0  # Needs upgrade
    fi

    # Simple string comparison
    if [[ "$current" == "$new" ]]; then
        return 1  # Same version
    fi

    # Different version, needs upgrade
    return 0
}

check_version() {
    local current_version
    local repo_version

    current_version=$(get_installed_version)
    repo_version=$(get_repo_version)

    log_info "Current version: $current_version"
    log_info "Repository version: $repo_version"

    if compare_versions "$current_version" "$repo_version"; then
        log_info "Upgrade available: $current_version → $repo_version"
        return 0
    else
        if [[ "$FORCE_UPGRADE" == true ]]; then
            log_warn "Versions are the same, but --force specified"
            return 0
        else
            log_info "System is already up to date (v$repo_version)"
            log_info "Use --force to reinstall/repair"
            exit 0
        fi
    fi
}

# ==============================================================================
#    Backup Creation
# ==============================================================================

create_backup() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_warn "Skipping backup (--no-backup specified)"
        echo ""
        return 0
    fi

    log_step "Creating backup..."

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_BASE/upgrade_backup_$timestamp"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would create backup at: $backup_dir"
        echo "$backup_dir"
        return 0
    fi

    mkdir -p "$backup_dir"

    # Backup critical files
    log_info "Backing up config.ini..."
    cp "$CONFIG_FILE" "$backup_dir/config.ini.bkp"

    log_info "Backing up bin scripts..."
    mkdir -p "$backup_dir/bin"
    if [[ -d "$INSTALL_BASE/bin" ]]; then
        cp -a "$INSTALL_BASE/bin/"* "$backup_dir/bin/" 2>/dev/null || true
    fi

    log_info "Backing up lib files..."
    mkdir -p "$backup_dir/lib"
    if [[ -d "$INSTALL_BASE/lib" ]]; then
        cp -a "$INSTALL_BASE/lib/"* "$backup_dir/lib/" 2>/dev/null || true
    fi

    # Backup Asterisk config
    if [[ -f /etc/asterisk/rpt.conf ]]; then
        log_info "Backing up rpt.conf..."
        cp /etc/asterisk/rpt.conf "$backup_dir/rpt.conf.bkp"
    fi

    # Backup crontab
    if crontab -u asterisk -l &>/dev/null; then
        log_info "Backing up crontab..."
        crontab -u asterisk -l > "$backup_dir/crontab.bkp" 2>/dev/null || true
    fi

    # Save version info
    echo "$(get_installed_version)" > "$backup_dir/VERSION.old"
    echo "$(get_repo_version)" > "$backup_dir/VERSION.new"

    log_success "Backup created: $backup_dir"
    echo "$backup_dir"
    return 0
}

# ==============================================================================
#    Platform Detection
# ==============================================================================

detect_platform() {
    # Detect AllStarLink appliance type to determine hardware expectations
    if dpkg -l 2>/dev/null | grep -q "ii.*asl3-appliance-pi"; then
        echo "pi"
    elif dpkg -l 2>/dev/null | grep -q "ii.*asl3-appliance-pc"; then
        echo "pc"
    elif dpkg -l 2>/dev/null | grep -q "ii.*asl3-appliance"; then
        echo "generic"
    else
        echo "unknown"
    fi
}

# ==============================================================================
#    Network Interface Detection
# ==============================================================================

detect_network_interfaces() {
    # Try to detect actual network interfaces
    local lan_iface=""
    local wlan_iface=""
    local vpn_iface=""
    local platform
    platform=$(detect_platform)

    # Find primary ethernet interface
    lan_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|enp|ens)' | head -1)
    [[ -z "$lan_iface" ]] && lan_iface="eth0"

    # Find wireless interface (platform-aware)
    wlan_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(wlan|wlp)' | head -1)
    if [[ -z "$wlan_iface" ]]; then
        # Only default to wlan0 on Pi platform (which always has wireless)
        if [[ "$platform" == "pi" ]]; then
            wlan_iface="wlan0"
        else
            # On PC/generic, leave empty if no wireless found
            wlan_iface=""
        fi
    fi

    # VPN interface (usually tun0 or wg0)
    vpn_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tun|wg)' | head -1)
    [[ -z "$vpn_iface" ]] && vpn_iface="tun0"

    echo "$lan_iface,$wlan_iface,$vpn_iface"
}

# ==============================================================================
#    Configuration Migration
# ==============================================================================

migrate_config() {
    log_step "Migrating configuration..."

    # Read existing config to extract user values
    set +u  # Temporarily allow undefined variables
    source "$CONFIG_FILE" || {
        log_error "Failed to source existing config"
        exit 3
    }
    set -u

    # Save critical user values
    local user_mynode="${MYNODE:-}"
    local user_nwszone="${NWSZONE:-}"
    local user_wustation="${WUSTATION:-}"
    local user_wuapikey="${WUAPIKEY:-}"
    local user_fetchlocal="${FETCHLOCAL:-0}"
    local user_fetchpoint="${FETCHPOINT:-localhost}"
    local user_retention="${RETENTION:-60}"

    # Check if network interface vars already exist
    local user_landevice="${landevice:-}"
    local user_wlandevice="${wlandevice:-}"
    local user_vpndevice="${vpndevice:-}"

    # If they don't exist, detect them
    if [[ -z "$user_landevice" ]] || [[ -z "$user_wlandevice" ]] || [[ -z "$user_vpndevice" ]]; then
        log_info "Detecting network interfaces..."
        IFS=',' read -r detected_lan detected_wlan detected_vpn <<< "$(detect_network_interfaces)"

        user_landevice="${user_landevice:-$detected_lan}"
        user_wlandevice="${user_wlandevice:-$detected_wlan}"
        user_vpndevice="${user_vpndevice:-$detected_vpn}"

        log_info "  LAN interface: $user_landevice"
        log_info "  WLAN interface: $user_wlandevice"
        log_info "  VPN interface: $user_vpndevice"
    else
        log_info "Using existing network interface settings:"
        log_info "  LAN interface: $user_landevice"
        log_info "  WLAN interface: $user_wlandevice"
        log_info "  VPN interface: $user_vpndevice"
    fi

    # Validate critical values
    if [[ -z "$user_mynode" ]] || [[ "$user_mynode" == "%MYNODE%" ]]; then
        log_error "MYNODE not set in config.ini"
        log_error "Cannot upgrade without valid node number"
        exit 3
    fi

    # Create new config from template
    local temp_config="/tmp/config.ini.new.$$"
    cp "$REPO_DIR/app_rpt/config.ini" "$temp_config"

    # Replace placeholders with user values
    sed -i "s/MYNODE=%MYNODE%/MYNODE=$user_mynode/g" "$temp_config"
    sed -i "s/NWSZONE=XXX000/NWSZONE=$user_nwszone/g" "$temp_config"
    sed -i "s/WUSTATION=empty/WUSTATION=$user_wustation/g" "$temp_config"
    sed -i "s/WUAPIKEY=empty/WUAPIKEY=$user_wuapikey/g" "$temp_config"
    sed -i "s/FETCHLOCAL=0/FETCHLOCAL=$user_fetchlocal/g" "$temp_config"
    sed -i "s/FETCHPOINT=localhost/FETCHPOINT=$user_fetchpoint/g" "$temp_config"
    sed -i "s/RETENTION=60/RETENTION=$user_retention/g" "$temp_config"

    # Update network interface variables
    sed -i "s/landevice=eth0/landevice=$user_landevice/g" "$temp_config"
    sed -i "s/wlandevice=wlan0/wlandevice=$user_wlandevice/g" "$temp_config"
    sed -i "s/vpndevice=tun0/vpndevice=$user_vpndevice/g" "$temp_config"

    # Replace %%BASEDIR%% placeholder
    sed -i "s|%%BASEDIR%%|$INSTALL_BASE|g" "$temp_config"

    # Add version marker
    sed -i "s|###VERSION=.*|###VERSION=$(get_repo_version)|g" "$temp_config"

    # Validate new config can be sourced
    if ! bash -c "set -euo pipefail; source '$temp_config'" 2>/dev/null; then
        log_error "New config.ini failed validation"
        log_error "Aborting upgrade"
        rm -f "$temp_config"
        exit 3
    fi

    log_success "Configuration migrated successfully"
    echo "$temp_config"
}

# ==============================================================================
#    Script Installation
# ==============================================================================

install_scripts() {
    local temp_config="$1"

    log_step "Installing scripts..."

    # CRITICAL: Install common.sh FIRST before updating any other scripts
    log_info "Installing common.sh (required by all scripts)..."

    local temp_common="/tmp/common.sh.new.$$"
    cp "$REPO_DIR/app_rpt/bin/common.sh" "$temp_common"
    sed -i "s|%%BASEDIR%%|$INSTALL_BASE|g" "$temp_common"

    if [[ "$DRY_RUN" == false ]]; then
        cp "$temp_common" "$INSTALL_BASE/bin/common.sh"
        chmod 755 "$INSTALL_BASE/bin/common.sh"
        chown asterisk:asterisk "$INSTALL_BASE/bin/common.sh"
    fi
    rm -f "$temp_common"

    # Test that common.sh can be sourced
    if [[ "$DRY_RUN" == false ]]; then
        if ! sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh'" 2>/dev/null; then
            log_error "common.sh failed to source correctly"
            log_error "Aborting upgrade"
            exit 4
        fi
        log_success "common.sh installed and validated"
    else
        log_info "[DRY RUN] Would install common.sh"
    fi

    # Now install all other scripts
    local script_count=0
    for script in "$REPO_DIR/app_rpt/bin/"*.sh; do
        local script_name
        script_name=$(basename "$script")

        # Skip common.sh (already installed)
        [[ "$script_name" == "common.sh" ]] && continue

        log_info "Installing $script_name..."

        local temp_script="/tmp/$script_name.new.$$"
        cp "$script" "$temp_script"
        sed -i "s|%%BASEDIR%%|$INSTALL_BASE|g" "$temp_script"

        if [[ "$DRY_RUN" == false ]]; then
            cp "$temp_script" "$INSTALL_BASE/bin/$script_name"
            chmod 755 "$INSTALL_BASE/bin/$script_name"
            chown asterisk:asterisk "$INSTALL_BASE/bin/$script_name"
        fi

        rm -f "$temp_script"
        ((script_count++))
    done

    log_success "Installed $script_count scripts"

    # Install utility scripts (install, upgrade, repair, uninstall)
    log_info "Installing utility scripts..."
    local util_count=0

    # Create util directory if it doesn't exist
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$INSTALL_BASE/util"
    fi

    # Copy utility scripts from repo root to /opt/app_rpt/util/
    local util_scripts=("install.sh" "upgrade.sh" "repair.sh" "uninstall.sh")

    for util_name in "${util_scripts[@]}"; do
        if [[ -f "$REPO_DIR/$util_name" ]]; then
            log_info "Installing $util_name..."

            local temp_util="/tmp/$util_name.new.$$"
            cp "$REPO_DIR/$util_name" "$temp_util"
            sed -i "s|%%BASEDIR%%|$INSTALL_BASE|g" "$temp_util"

            if [[ "$DRY_RUN" == false ]]; then
                cp "$temp_util" "$INSTALL_BASE/util/$util_name"
                chmod 755 "$INSTALL_BASE/util/$util_name"
                chown asterisk:asterisk "$INSTALL_BASE/util/$util_name"
            fi

            rm -f "$temp_util"
            ((util_count++))
        else
            log_info "Utility script not found: $util_name"
        fi
    done

    if [[ $util_count -gt 0 ]]; then
        log_success "Installed $util_count utility scripts"
    else
        log_info "[DRY RUN] Would install utility scripts"
    fi

    # Install new config.ini
    if [[ "$DRY_RUN" == false ]]; then
        log_info "Installing new config.ini..."
        cp "$temp_config" "$CONFIG_FILE"
        chmod 644 "$CONFIG_FILE"
        chown asterisk:asterisk "$CONFIG_FILE"
        log_success "config.ini updated"
    else
        log_info "[DRY RUN] Would install new config.ini"
    fi

    rm -f "$temp_config"

    # Remove conflicting Asterisk en directory if it exists
    if [[ -d "/var/lib/asterisk/sounds/en" ]] || [[ -d "$INSTALL_BASE/sounds/en" ]]; then
        log_info "Removing conflicting Asterisk en directory..."
        if [[ "$DRY_RUN" == false ]]; then
            rm -rf /var/lib/asterisk/sounds/en 2>/dev/null || true
            rm -rf "$INSTALL_BASE/sounds/en" 2>/dev/null || true
            log_success "Removed conflicting en directory (conflicts with app_rpt__ultra vocabulary)"
        else
            log_info "[DRY RUN] Would remove conflicting en directory"
        fi
    fi
}

# ==============================================================================
#    Post-Upgrade Validation
# ==============================================================================

validate_installation() {
    log_step "Validating installation..."

    local errors=0

    # Check all required scripts exist
    log_info "Checking script files..."
    local required_scripts=(
        "common.sh" "asterisk.sh" "cmdparser.sh" "configkeeper.sh"
        "ctkeeper.sh" "ctwriter.sh" "datadumper.sh" "datekeeper.sh"
        "gpio.sh" "idkeeper.sh" "msgreader.sh" "msgwriter.sh"
        "restart.sh" "sayip.sh" "speaktext.sh" "statekeeper.sh"
        "system.sh" "tailkeeper.sh" "timekeeper.sh" "weatheralert.sh"
        "weatherkeeper.sh" "wireless.sh"
    )

    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$INSTALL_BASE/bin/$script" ]]; then
            log_error "Missing: $INSTALL_BASE/bin/$script"
            ((errors++))
        elif [[ ! -x "$INSTALL_BASE/bin/$script" ]]; then
            log_error "Not executable: $INSTALL_BASE/bin/$script"
            ((errors++))
        fi
    done

    # Test common.sh can be sourced
    log_info "Testing common.sh..."
    if ! sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh'" 2>/dev/null; then
        log_error "common.sh failed to source"
        ((errors++))
    fi

    # Test config.ini is valid
    log_info "Validating config.ini..."
    if ! sudo -u asterisk bash -c "source '$CONFIG_FILE'" 2>/dev/null; then
        log_error "config.ini contains errors"
        ((errors++))
    fi

    # Check required config variables
    log_info "Checking config variables..."
    set +u
    source "$CONFIG_FILE"
    local required_vars=(
        "MYNODE" "BASEDIR" "BINDIR" "SOUNDS" "RPTCONF"
        "landevice" "wlandevice" "vpndevice"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing config variable: $var"
            ((errors++))
        fi
    done
    set -u

    # Check Asterisk config
    if command -v asterisk &>/dev/null; then
        log_info "Testing Asterisk configuration..."
        if ! asterisk -rx "core show version" &>/dev/null; then
            log_warn "Asterisk not running or not responding (not critical)"
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi

    log_success "All validation checks passed"
    return 0
}

# ==============================================================================
#    Version File Update
# ==============================================================================

update_version_file() {
    log_step "Updating version information..."

    if [[ "$DRY_RUN" == false ]]; then
        echo "$(get_repo_version)" > "$VERSION_FILE"
        chown asterisk:asterisk "$VERSION_FILE"
        log_success "Version set to $(get_repo_version)"
    else
        log_info "[DRY RUN] Would set version to $(get_repo_version)"
    fi
}

# ==============================================================================
#    Fix Ownership and Permissions
# ==============================================================================

fix_permissions() {
    log_step "Verifying ownership and permissions..."

    if [[ "$DRY_RUN" == false ]]; then
        # Ensure all of /opt/app_rpt is owned by asterisk:asterisk
        chown -R asterisk:asterisk "$INSTALL_BASE"
        log_info "Set ownership on $INSTALL_BASE"

        # Ensure critical Asterisk directories have correct ownership
        local asterisk_dirs=(
            "/var/lib/asterisk"
            "/var/log/asterisk"
            "/var/spool/asterisk"
            "/var/run/asterisk"
        )

        for dir in "${asterisk_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                chown -R asterisk:asterisk "$dir"
            fi
        done

        # Ensure log file has proper permissions
        if [[ -f /var/log/app_rpt.log ]]; then
            chown asterisk:asterisk /var/log/app_rpt.log
            chmod 664 /var/log/app_rpt.log
        fi

        log_success "Ownership and permissions verified"
    else
        log_info "[DRY RUN] Would verify ownership and permissions"
    fi
}

# ==============================================================================
#    Rollback Function
# ==============================================================================

rollback_upgrade() {
    local backup_dir="$1"

    log_error "Upgrade failed, rolling back..."

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Backup directory not found: $backup_dir"
        log_error "Cannot rollback automatically"
        return 1
    fi

    log_info "Restoring from backup: $backup_dir"

    # Restore config.ini
    if [[ -f "$backup_dir/config.ini.bkp" ]]; then
        cp "$backup_dir/config.ini.bkp" "$CONFIG_FILE"
        log_info "✓ Restored config.ini"
    fi

    # Restore bin scripts
    if [[ -d "$backup_dir/bin" ]]; then
        rm -rf "$INSTALL_BASE/bin/"*
        cp -a "$backup_dir/bin/"* "$INSTALL_BASE/bin/"
        log_info "✓ Restored bin scripts"
    fi

    # Restore lib files
    if [[ -d "$backup_dir/lib" ]]; then
        cp -a "$backup_dir/lib/"* "$INSTALL_BASE/lib/"
        log_info "✓ Restored lib files"
    fi

    # Restore VERSION
    if [[ -f "$backup_dir/VERSION.old" ]]; then
        cp "$backup_dir/VERSION.old" "$VERSION_FILE"
        log_info "✓ Restored version file"
    fi

    log_info "Rollback complete"
    log_info "System restored to pre-upgrade state"

    return 0
}

# ==============================================================================
#    Upgrade Summary
# ==============================================================================

show_upgrade_summary() {
    local current_version="$1"
    local new_version="$2"

    echo ""
    echo "========================================"
    echo "  app_rpt__ultra Upgrade Summary"
    echo "========================================"
    echo ""
    echo "Current version: $current_version"
    echo "New version:     $new_version"
    echo ""
    echo "Changes in v$new_version:"
    echo "  • NEW: common.sh shared library for all scripts"
    echo "  • IMPROVED: Better error handling with set -euo pipefail"
    echo "  • IMPROVED: Consistent logging across all scripts"
    echo "  • IMPROVED: Better variable quoting and validation"
    echo "  • FIXED: sayip.sh wlan announcement now says 'wlan' correctly"
    echo "  • FIXED: Network interface variables now properly defined"
    echo "  • ADDED: GPL license headers to all scripts"
    echo "  • ENHANCED: 21 scripts updated with improvements"
    echo ""
    echo "This upgrade will:"
    echo "  1. Create backup of current installation"
    echo "  2. Migrate your config.ini (preserving settings)"
    echo "  3. Install common.sh (new dependency)"
    echo "  4. Update all scripts"
    echo "  5. Validate the installation"
    echo "  6. Update version to $new_version"
    echo ""
    echo "Backup location: $BACKUP_BASE/upgrade_backup_*"
    echo ""
}

# ==============================================================================
#    Command Line Parsing
# ==============================================================================

# Parse command line options
DRY_RUN=false
FORCE_UPGRADE=false
SKIP_BACKUP=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE_UPGRADE=true; shift ;;
        --no-backup) SKIP_BACKUP=true; shift ;;
        --auto-yes) AUTO_YES=true; shift ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# ==============================================================================
#    Main Execution
# ==============================================================================

main() {
    local current_version
    local repo_version
    local backup_dir=""

    # Banner
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  app_rpt__ultra Upgrade Tool          ║"
    echo "║  Version $SCRIPT_VERSION                        ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Pre-flight
    check_prerequisites
    current_version=$(get_installed_version)
    repo_version=$(get_repo_version)
    check_version

    # Show summary
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    show_upgrade_summary "$current_version" "$repo_version"

    # Confirm with user
    if [[ "$AUTO_YES" == false ]] && [[ "$DRY_RUN" == false ]]; then
        read -p "Proceed with upgrade? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Upgrade cancelled by user"
            exit 0
        fi
    fi

    echo ""

    # Execute upgrade steps
    set +e  # Don't exit on error, handle it ourselves

    # Step 1: Backup
    backup_dir=$(create_backup)
    if [[ $? -ne 0 ]] && [[ "$SKIP_BACKUP" == false ]]; then
        log_error "Backup failed"
        exit 2
    fi
    echo ""

    # Step 2: Migrate config
    local new_config
    new_config=$(migrate_config)
    if [[ $? -ne 0 ]]; then
        log_error "Config migration failed"
        exit 3
    fi
    echo ""

    # Step 3: Install scripts
    install_scripts "$new_config"
    if [[ $? -ne 0 ]]; then
        log_error "Script installation failed"
        [[ -n "$backup_dir" ]] && rollback_upgrade "$backup_dir"
        exit 4
    fi
    echo ""

    # Step 4: Validate (skip in dry-run)
    if [[ "$DRY_RUN" == false ]]; then
        if ! validate_installation; then
            log_error "Validation failed"
            rollback_upgrade "$backup_dir"
            exit 5
        fi
        echo ""
    fi

    # Step 5: Fix ownership and permissions
    fix_permissions
    echo ""

    # Step 6: Update version
    update_version_file
    echo ""

    set -e

    # Success!
    echo "╔═══════════════════════════════════════╗"
    echo "║  ✓ Upgrade Complete!                  ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""
    log_success "Upgraded from v$current_version to v$repo_version"
    if [[ -n "$backup_dir" ]]; then
        log_info "Backup saved to: $backup_dir"
    fi
    echo ""
    log_info "Next steps:"
    echo "  1. Review /var/log/app_rpt.log for any errors"
    echo "  2. Test critical functions (IDs, messages, etc.)"
    echo "  3. Monitor system for 24 hours"
    if [[ -n "$backup_dir" ]]; then
        echo "  4. If issues occur, restore from: $backup_dir"
    fi
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_warn "DRY RUN MODE - No actual changes were made"
        echo ""
    fi
}

# Execute main
main "$@"
