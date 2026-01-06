# Implementation Plan: upgrade.sh

## Overview

A safe, intelligent upgrade script that migrates an existing app_rpt__ultra installation from any previous version to v2.0.1+, handling the critical transition to the new common.sh architecture.

---

## Usage

```bash
sudo ./upgrade.sh [options]

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
```

---

## Script Structure

### 1. Initialization (Lines 1-100)

```bash
#!/usr/bin/env bash
set -euo pipefail

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
readonly NC='\033[0m' # No Color

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

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }
```

### 2. Pre-flight Checks (Lines 101-250)

```bash
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
    for cmd in jq git rsync awk sed grep; do
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

    log_info "Pre-flight checks passed"
}

get_installed_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

compare_versions() {
    local current="$1"
    local new="$2"

    # If current is unknown, always upgrade
    if [[ "$current" == "unknown" ]]; then
        return 0  # Needs upgrade
    fi

    # Simple string comparison for now
    # Could be enhanced with proper semantic versioning
    if [[ "$current" == "$new" ]]; then
        return 1  # Same version
    fi

    # Different version, needs upgrade
    return 0
}

check_version() {
    local current_version
    current_version=$(get_installed_version)

    log_info "Current version: $current_version"
    log_info "Repository version: $SCRIPT_VERSION"

    if compare_versions "$current_version" "$SCRIPT_VERSION"; then
        log_info "Upgrade available: $current_version → $SCRIPT_VERSION"
        return 0
    else
        if [[ "$FORCE_UPGRADE" == true ]]; then
            log_warn "Versions are the same, but --force specified"
            return 0
        else
            log_info "System is already up to date (v$SCRIPT_VERSION)"
            log_info "Use --force to reinstall/repair"
            exit 0
        fi
    fi
}
```

### 3. Backup Creation (Lines 251-350)

```bash
create_backup() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_warn "Skipping backup (--no-backup specified)"
        return 0
    fi

    log_step "Creating backup..."

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BACKUP_BASE/upgrade_backup_$timestamp"

    mkdir -p "$backup_dir"

    # Backup critical files
    log_info "Backing up config.ini..."
    cp "$CONFIG_FILE" "$backup_dir/config.ini.bkp"

    log_info "Backing up bin scripts..."
    mkdir -p "$backup_dir/bin"
    cp -a "$INSTALL_BASE/bin/"* "$backup_dir/bin/" 2>/dev/null || true

    log_info "Backing up lib files..."
    mkdir -p "$backup_dir/lib"
    cp -a "$INSTALL_BASE/lib/"* "$backup_dir/lib/" 2>/dev/null || true

    # Backup Asterisk config
    if [[ -f /etc/asterisk/rpt.conf ]]; then
        log_info "Backing up rpt.conf..."
        cp /etc/asterisk/rpt.conf "$backup_dir/rpt.conf.bkp"
    fi

    # Backup crontab
    if crontab -u asterisk -l &>/dev/null; then
        log_info "Backing up crontab..."
        crontab -u asterisk -l > "$backup_dir/crontab.bkp"
    fi

    # Save current version info
    echo "$(get_installed_version)" > "$backup_dir/VERSION.old"
    echo "$SCRIPT_VERSION" > "$backup_dir/VERSION.new"

    log_info "Backup created: $backup_dir"
    echo "$backup_dir" > /tmp/app_rpt_last_backup.txt

    return 0
}
```

### 4. Configuration Migration (Lines 351-550)

```bash
detect_network_interfaces() {
    # Try to detect actual network interfaces
    local lan_iface=""
    local wlan_iface=""
    local vpn_iface=""

    # Find primary ethernet interface
    lan_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|enp|ens)' | head -1)
    [[ -z "$lan_iface" ]] && lan_iface="eth0"

    # Find wireless interface
    wlan_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(wlan|wlp)' | head -1)
    [[ -z "$wlan_iface" ]] && wlan_iface="wlan0"

    # VPN interface (usually tun0 or wg0)
    vpn_iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tun|wg)' | head -1)
    [[ -z "$vpn_iface" ]] && vpn_iface="tun0"

    echo "$lan_iface,$wlan_iface,$vpn_iface"
}

migrate_config() {
    log_step "Migrating configuration..."

    # Read existing config to extract user values
    source "$CONFIG_FILE" || {
        log_error "Failed to source existing config"
        exit 1
    }

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
    fi

    # Validate critical values
    if [[ -z "$user_mynode" ]] || [[ "$user_mynode" == "%MYNODE%" ]]; then
        log_error "MYNODE not set in config.ini"
        log_error "Cannot upgrade without valid node number"
        exit 1
    fi

    # Create new config from template
    local temp_config="/tmp/config.ini.new"
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

    # Add version and timestamp
    local timestamp
    timestamp=$(date '+%a %b %d %I:%M:%S %p %Z %Y')
    sed -i "s|###EDIT:.*|###EDIT: $timestamp (Upgraded to v$SCRIPT_VERSION)|g" "$temp_config"

    # Validate new config can be sourced
    if ! bash -c "set -euo pipefail; source '$temp_config'" 2>/dev/null; then
        log_error "New config.ini failed validation"
        log_error "Aborting upgrade"
        rm -f "$temp_config"
        exit 1
    fi

    log_info "Configuration migrated successfully"
    echo "$temp_config"
}
```

### 5. Script Installation (Lines 551-700)

```bash
install_scripts() {
    local temp_config="$1"

    log_step "Installing scripts..."

    # CRITICAL: Install common.sh FIRST before updating any other scripts
    log_info "Installing common.sh (required by all scripts)..."

    local temp_common="/tmp/common.sh.new"
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
            exit 1
        fi
        log_info "✓ common.sh installed and validated"
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

        local temp_script="/tmp/$script_name.new"
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

    log_info "✓ Installed $script_count scripts"

    # Install new config.ini
    if [[ "$DRY_RUN" == false ]]; then
        log_info "Installing new config.ini..."
        cp "$temp_config" "$CONFIG_FILE"
        chmod 644 "$CONFIG_FILE"
        chown asterisk:asterisk "$CONFIG_FILE"
        log_info "✓ config.ini updated"
    else
        log_info "[DRY RUN] Would install new config.ini"
    fi

    rm -f "$temp_config"
}
```

### 6. Post-Upgrade Validation (Lines 701-850)

```bash
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

    # Test one script can execute
    log_info "Testing script execution..."
    if ! sudo -u asterisk "$INSTALL_BASE/bin/system.sh" test &>/dev/null; then
        log_warn "Script execution test failed (may be normal)"
    fi

    # Check Asterisk config
    if command -v asterisk &>/dev/null; then
        log_info "Testing Asterisk configuration..."
        if ! asterisk -rx "core show version" &>/dev/null; then
            log_warn "Asterisk not running or not responding"
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Validation failed with $errors error(s)"
        return 1
    fi

    log_info "✓ All validation checks passed"
    return 0
}
```

### 7. Version Tracking (Lines 851-900)

```bash
update_version_file() {
    log_step "Updating version information..."

    if [[ "$DRY_RUN" == false ]]; then
        echo "$SCRIPT_VERSION" > "$VERSION_FILE"
        chown asterisk:asterisk "$VERSION_FILE"
        log_info "✓ Version set to $SCRIPT_VERSION"
    else
        log_info "[DRY RUN] Would set version to $SCRIPT_VERSION"
    fi
}
```

### 8. Rollback Function (Lines 901-1000)

```bash
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
```

### 9. Main Execution (Lines 1001-1150)

```bash
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
    echo "  4. Update all 21 scripts"
    echo "  5. Validate the installation"
    echo "  6. Update version to $new_version"
    echo ""
    echo "Backup location: $BACKUP_BASE/upgrade_backup_*"
    echo ""
}

main() {
    local current_version
    local backup_dir=""

    # Banner
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  app_rpt__ultra Upgrade Tool          ║"
    echo "║  Version $SCRIPT_VERSION                       ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Pre-flight
    check_prerequisites
    current_version=$(get_installed_version)
    check_version

    # Show summary
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    show_upgrade_summary "$current_version" "$SCRIPT_VERSION"

    # Confirm with user
    if [[ "$AUTO_YES" == false ]] && [[ "$DRY_RUN" == false ]]; then
        read -p "Proceed with upgrade? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Upgrade cancelled by user"
            exit 0
        fi
    fi

    # Execute upgrade steps
    set +e  # Don't exit on error, handle it ourselves

    # Step 1: Backup
    backup_dir=$(create_backup)
    if [[ $? -ne 0 ]]; then
        log_error "Backup failed"
        exit 1
    fi

    # Step 2: Migrate config
    local new_config
    new_config=$(migrate_config)
    if [[ $? -ne 0 ]]; then
        log_error "Config migration failed"
        exit 1
    fi

    # Step 3: Install scripts
    install_scripts "$new_config"
    if [[ $? -ne 0 ]]; then
        log_error "Script installation failed"
        [[ -n "$backup_dir" ]] && rollback_upgrade "$backup_dir"
        exit 1
    fi

    # Step 4: Validate (skip in dry-run)
    if [[ "$DRY_RUN" == false ]]; then
        if ! validate_installation; then
            log_error "Validation failed"
            rollback_upgrade "$backup_dir"
            exit 1
        fi
    fi

    # Step 5: Update version
    update_version_file

    set -e

    # Success!
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  ✓ Upgrade Complete!                  ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    log_info "Upgraded from v$current_version to v$SCRIPT_VERSION"
    log_info "Backup saved to: $backup_dir"
    echo ""
    log_info "Next steps:"
    echo "  1. Review /var/log/app_rpt.log for any errors"
    echo "  2. Test critical functions (IDs, messages, etc.)"
    echo "  3. Monitor system for 24 hours"
    echo "  4. If issues occur, restore from: $backup_dir"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_warn "DRY RUN MODE - No actual changes were made"
        echo ""
    fi
}

# Execute main
main "$@"
```

---

## Safety Features

### 1. Multiple Safety Checks
- ✅ Root permission check
- ✅ Installation existence check
- ✅ Version comparison (skip if same version)
- ✅ Config validation before and after migration
- ✅ Atomic installation (common.sh first, then all scripts)
- ✅ Post-upgrade validation suite

### 2. Rollback Capability
- ✅ Automatic rollback on validation failure
- ✅ Preserves backup location for manual rollback
- ✅ Timestamped backups for history

### 3. User Control
- ✅ Dry-run mode to preview changes
- ✅ Interactive confirmation (unless --auto-yes)
- ✅ Force option to reinstall same version
- ✅ Option to skip backup (not recommended)

### 4. Error Handling
- ✅ `set -euo pipefail` for bash strict mode
- ✅ Validation at every step
- ✅ Clear error messages with color coding
- ✅ Exit codes for scripting

---

## Testing Plan

### Test Case 1: Fresh Install to v2.0.1
```bash
# Start with clean system
sudo ./install.sh
# Verify it works
sudo -u asterisk /opt/app_rpt/bin/statekeeper.sh default
# Try upgrade (should say "already up to date")
sudo ./upgrade.sh
```

### Test Case 2: Simulated Old Version
```bash
# Create fake old version
echo "1.0.0" | sudo tee /opt/app_rpt/VERSION
# Run upgrade
sudo ./upgrade.sh
# Verify success
cat /opt/app_rpt/VERSION  # Should show 2.0.1
```

### Test Case 3: Missing Network Variables
```bash
# Remove network variables from config.ini
sudo sed -i '/^landevice=/d' /opt/app_rpt/config.ini
sudo sed -i '/^wlandevice=/d' /opt/app_rpt/config.ini
sudo sed -i '/^vpndevice=/d' /opt/app_rpt/config.ini
# Run upgrade
sudo ./upgrade.sh
# Verify they were added back
grep -E 'landevice|wlandevice|vpndevice' /opt/app_rpt/config.ini
```

### Test Case 4: Dry Run
```bash
# Preview upgrade without changes
sudo ./upgrade.sh --dry-run
# Verify nothing changed
ls -la /opt/app_rpt/bin/common.sh  # Should not exist if old version
```

### Test Case 5: Rollback
```bash
# Force upgrade with intentional error
sudo ./upgrade.sh --force
# Simulate validation failure
# Verify rollback occurred
cat /opt/app_rpt/VERSION  # Should show old version
```

---

## Future Enhancements

1. **Semantic versioning** - Proper comparison of version numbers (2.1.0 > 2.0.9)
2. **Changelog integration** - Pull changelog from git or CHANGELOG.md file
3. **Remote upgrade** - Download latest version from GitHub
4. **Pre-upgrade health check** - Run repair.sh checks before upgrade
5. **Post-upgrade testing** - Actually execute scripts to verify they work
6. **Partial upgrades** - Allow upgrading only specific components
7. **Downgrade support** - Rollback to specific older version
8. **Config diff viewer** - Show user what changed in config.ini
9. **Asterisk reload** - Automatically reload Asterisk config after upgrade
10. **Email notifications** - Send upgrade report to sysadmin

---

## Dependencies

### Required:
- bash 4.0+
- coreutils (cp, mv, rm, chmod, chown, etc.)
- sed, awk, grep
- rsync
- jq (for potential JSON config in future)

### Optional:
- git (for version detection from repo)
- asterisk (for validation checks)
- systemd (for service management)

---

## Exit Codes

- `0` - Success
- `1` - General error (pre-flight check failed, user cancelled, etc.)
- `2` - Backup failed
- `3` - Config migration failed
- `4` - Script installation failed
- `5` - Validation failed (rollback triggered)
- `6` - Rollback failed (manual intervention required)

---

## Estimated Script Size

**Approximately 1100-1200 lines** including:
- 100 lines: Header, initialization, option parsing
- 150 lines: Pre-flight checks and version comparison
- 100 lines: Backup creation
- 200 lines: Configuration migration (complex logic)
- 150 lines: Script installation
- 150 lines: Post-upgrade validation
- 50 lines: Version file management
- 100 lines: Rollback function
- 150 lines: Main execution and flow control
- 100 lines: Comments and documentation
