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

readonly SCRIPT_NAME=$(basename "$0")
readonly INSTALL_DIR="/opt/app_rpt"
readonly RECORDINGS_DIR="/opt/asterisk"
readonly ASTERISK_SOUNDS_1="/var/lib/asterisk/sounds"
readonly ASTERISK_SOUNDS_2="/usr/share/asterisk/sounds"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse command line arguments
FORCE_YES=false
KEEP_RECORDINGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            FORCE_YES=true
            shift
            ;;
        --keep-recordings)
            KEEP_RECORDINGS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $SCRIPT_NAME [OPTIONS]"
            echo ""
            echo "Uninstall app_rpt__ultra from this system."
            echo ""
            echo "Options:"
            echo "  -y, --yes           Non-interactive mode, answer yes to all prompts"
            echo "  --keep-recordings   Keep recordings in $RECORDINGS_DIR"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$FORCE_YES" == "true" ]]; then
        return 0
    fi

    local yn
    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n]: " yn
        yn=${yn:-y}
    else
        read -r -p "$prompt [y/N]: " yn
        yn=${yn:-n}
    fi

    case $yn in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

remove_crontab() {
    log_info "Removing crontab entries for asterisk user..."

    if crontab -u asterisk -l &>/dev/null; then
        # Remove all app_rpt__ultra entries and comments from crontab
        local temp_cron
        temp_cron=$(mktemp)

        crontab -u asterisk -l 2>/dev/null | grep -v "app_rpt__ultra" | grep -v "/opt/app_rpt/bin/" > "$temp_cron" || true

        if [[ -s "$temp_cron" ]]; then
            crontab -u asterisk "$temp_cron"
            log_info "Removed app_rpt__ultra entries from crontab"
        else
            crontab -u asterisk -r 2>/dev/null || true
            log_info "Removed empty crontab for asterisk user"
        fi

        rm -f "$temp_cron"
    else
        log_info "No crontab found for asterisk user"
    fi
}

remove_symlinks() {
    log_info "Removing sound directory symlinks..."

    for dir in "$ASTERISK_SOUNDS_1" "$ASTERISK_SOUNDS_2"; do
        if [[ -L "$dir" ]]; then
            rm -f "$dir"
            log_info "Removed symlink: $dir"
        elif [[ -d "$dir" ]]; then
            log_warn "$dir exists but is not a symlink, skipping"
        fi
    done
}

remove_install_dir() {
    log_info "Removing installation directory..."

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log_info "Removed: $INSTALL_DIR"
    else
        log_info "Installation directory not found: $INSTALL_DIR"
    fi
}

remove_recordings() {
    if [[ "$KEEP_RECORDINGS" == "true" ]]; then
        log_info "Keeping recordings directory as requested"
        return
    fi

    if [[ -d "$RECORDINGS_DIR" ]]; then
        local recording_count
        recording_count=$(find "$RECORDINGS_DIR" -type f 2>/dev/null | wc -l)

        if [[ $recording_count -gt 0 ]]; then
            log_warn "Found $recording_count file(s) in $RECORDINGS_DIR"

            if confirm "Delete recordings directory and all contents?"; then
                rm -rf "$RECORDINGS_DIR"
                log_info "Removed: $RECORDINGS_DIR"
            else
                log_info "Keeping recordings directory"
            fi
        else
            rm -rf "$RECORDINGS_DIR"
            log_info "Removed empty recordings directory: $RECORDINGS_DIR"
        fi
    fi
}

remove_asterisk_configs() {
    log_info "Checking for app_rpt__ultra Asterisk configuration..."

    local configs_removed=0

    # Check for custom extensions
    if [[ -f "/etc/asterisk/custom/extensions.conf" ]]; then
        if confirm "Remove /etc/asterisk/custom/extensions.conf?"; then
            rm -f "/etc/asterisk/custom/extensions.conf"
            log_info "Removed: /etc/asterisk/custom/extensions.conf"
            ((configs_removed++))
        fi
    fi

    # Don't remove rpt.conf as it may have user customizations
    if [[ -f "/etc/asterisk/rpt.conf" ]]; then
        log_warn "Not removing /etc/asterisk/rpt.conf - contains user configuration"
        log_warn "You may need to restore your original rpt.conf manually"
    fi

    if [[ $configs_removed -eq 0 ]]; then
        log_info "No configuration files removed"
    fi
}

restore_asterisk_sounds() {
    log_info "Asterisk sound directories have been unlinked."
    log_warn "You may need to reinstall Asterisk sounds:"
    log_warn "  apt install asterisk-sounds-core"
    log_warn "  apt install asterisk-sounds-extra  (optional)"
}

print_summary() {
    echo ""
    echo "=============================================="
    echo "       app_rpt__ultra Uninstall Complete"
    echo "=============================================="
    echo ""
    log_info "The following actions were performed:"
    echo "  - Removed crontab entries for asterisk user"
    echo "  - Removed sound directory symlinks"
    echo "  - Removed installation directory ($INSTALL_DIR)"

    if [[ "$KEEP_RECORDINGS" == "true" ]]; then
        echo "  - Kept recordings directory ($RECORDINGS_DIR)"
    else
        echo "  - Removed/checked recordings directory"
    fi

    echo ""
    log_warn "Manual steps you may need to perform:"
    echo "  1. Restore original /etc/asterisk/rpt.conf if needed"
    echo "  2. Reinstall Asterisk sounds if needed:"
    echo "     apt install asterisk-sounds-core"
    echo "  3. Restart Asterisk: systemctl restart asterisk"
    echo ""
}

main() {
    echo ""
    echo "=============================================="
    echo "       app_rpt__ultra Uninstaller"
    echo "=============================================="
    echo ""

    check_root

    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_warn "app_rpt__ultra does not appear to be installed"
        log_warn "Installation directory not found: $INSTALL_DIR"

        if ! confirm "Continue with cleanup anyway?"; then
            log_info "Uninstall cancelled"
            exit 0
        fi
    fi

    echo ""
    log_warn "This will remove app_rpt__ultra from your system."
    echo ""

    if ! confirm "Are you sure you want to uninstall?"; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    echo ""

    remove_crontab
    remove_symlinks
    remove_install_dir
    remove_recordings
    remove_asterisk_configs
    restore_asterisk_sounds
    print_summary
}

main "$@"
