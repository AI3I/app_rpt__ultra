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

set -uo pipefail

# ==============================================================================
#    repair.sh - System health check and repair tool for app_rpt__ultra
# ==============================================================================
#
#    This script performs comprehensive health checks on an app_rpt__ultra
#    installation and can automatically repair common issues.
#

# Version information
readonly SCRIPT_VERSION="2.0.1"
readonly SCRIPT_NAME="repair.sh"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation paths
readonly INSTALL_BASE="/opt/app_rpt"
readonly CONFIG_FILE="$INSTALL_BASE/config.ini"
readonly VERSION_FILE="$INSTALL_BASE/VERSION"
readonly LOG_FILE="/var/log/app_rpt.log"

# Expected file counts
readonly EXPECTED_SCRIPTS=22  # Including common.sh
readonly EXPECTED_CRON_JOBS=7

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Counters for reporting
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0
FIXES_APPLIED=0

# ==============================================================================
#    Logging Functions
# ==============================================================================

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((CHECKS_PASSED++))
    [[ -n "$REPORT_FILE" ]] && echo "[PASS] $*" >> "$REPORT_FILE"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((CHECKS_FAILED++))
    [[ -n "$REPORT_FILE" ]] && echo "[FAIL] $*" >> "$REPORT_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((CHECKS_WARNING++))
    [[ -n "$REPORT_FILE" ]] && echo "[WARN] $*" >> "$REPORT_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    [[ -n "$REPORT_FILE" ]] && echo "[INFO] $*" >> "$REPORT_FILE"
}

log_fixed() {
    echo -e "${CYAN}[FIXED]${NC} $*"
    ((FIXES_APPLIED++))
    [[ -n "$REPORT_FILE" ]] && echo "[FIXED] $*" >> "$REPORT_FILE"
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${NC}$*"
        [[ -n "$REPORT_FILE" ]] && echo "  $*" >> "$REPORT_FILE"
    fi
}

# ==============================================================================
#    Repair Helper Functions
# ==============================================================================

ask_repair() {
    local question="$1"
    shift
    local fix_command="$*"

    if [[ "$CHECK_ONLY" == true ]]; then
        return 1  # Don't fix in check-only mode
    fi

    if [[ "$AUTO_FIX" == true ]]; then
        log_info "Auto-fixing: $question"
        eval "$fix_command"
        if [[ $? -eq 0 ]]; then
            log_fixed "$question"
            return 0
        else
            log_fail "Failed to fix: $question"
            return 1
        fi
    fi

    read -p "$(echo -e "${YELLOW}Repair:${NC} $question? [y/N] ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        eval "$fix_command"
        if [[ $? -eq 0 ]]; then
            log_fixed "$question"
            return 0
        else
            log_fail "Failed to fix: $question"
            return 1
        fi
    fi
    return 1
}

# ==============================================================================
#    Help Text
# ==============================================================================

show_help() {
    cat <<'EOF'
app_rpt__ultra System Repair Tool

Usage: sudo ./repair.sh [options]

Options:
  --check-only       Only check for problems, don't fix anything
  --auto-fix         Automatically fix all issues without prompting
  --verbose          Show detailed output for all checks
  --report FILE      Save detailed report to FILE
  --help             Show this help message

Examples:
  sudo ./repair.sh                    # Interactive repair with prompts
  sudo ./repair.sh --check-only       # Health check only, no repairs
  sudo ./repair.sh --auto-fix         # Fix everything automatically
  sudo ./repair.sh --verbose --report /tmp/health.txt

Check Categories:
  1. System Prerequisites   - Root access, asterisk user, required commands
  2. Directory Structure    - Expected directories and symlinks
  3. Script Files          - All 22 scripts present and executable
  4. Configuration         - config.ini validity and required variables
  5. Asterisk Config       - rpt.conf and Asterisk integration
  6. Cron Jobs            - Expected 7 cron jobs for asterisk user
  7. Sound Files          - Voice files and system sounds
  8. Log File             - Log file exists and is writable
  9. Runtime Tests        - Scripts can actually execute

Exit Codes:
  0 - All checks passed (system healthy)
  1 - Minor issues detected (warnings only)
  2 - Significant issues detected (failures)
  3 - Critical error (cannot proceed)

EOF
}

# ==============================================================================
#    System Prerequisites Checks
# ==============================================================================

check_system_basics() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  System Prerequisites                 ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check running as root
    if [[ $EUID -eq 0 ]]; then
        log_pass "Running as root"
    else
        log_fail "Not running as root (use sudo)"
        return 1
    fi

    # Check installation exists
    if [[ -d "$INSTALL_BASE" ]]; then
        log_pass "Installation directory exists: $INSTALL_BASE"
        if [[ "$VERBOSE" == true ]]; then
            local size
            size=$(du -sh "$INSTALL_BASE" 2>/dev/null | awk '{print $1}')
            log_verbose "Size: $size"
        fi
    else
        log_fail "Installation directory not found: $INSTALL_BASE"
        log_info "Run install.sh to install app_rpt__ultra"
        return 1
    fi

    # Check asterisk user exists
    if id asterisk &>/dev/null; then
        log_pass "asterisk user exists"
        log_verbose "UID: $(id -u asterisk), GID: $(id -g asterisk)"
    else
        log_fail "asterisk user not found"
        log_info "Install Asterisk/ASL3 before using app_rpt__ultra"
    fi

    # Check asterisk user groups
    local required_groups=("dialout" "audio")
    local optional_groups=("sudo" "plugdev")
    local missing_required=()

    for group in "${required_groups[@]}"; do
        if id -nG asterisk 2>/dev/null | grep -qw "$group"; then
            log_pass "asterisk user in $group group"
        else
            log_fail "asterisk user not in $group group"
            missing_required+=("$group")
        fi
    done

    for group in "${optional_groups[@]}"; do
        if id -nG asterisk 2>/dev/null | grep -qw "$group"; then
            log_verbose "asterisk user in $group group (optional)"
        else
            log_warn "asterisk user not in $group group (may be needed)"
        fi
    done

    # Offer to fix group membership
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        ask_repair "Add asterisk to required groups: ${missing_required[*]}" \
            "usermod -a -G $(IFS=,; echo "${missing_required[*]}") asterisk"
    fi

    # Check required commands
    local required_cmds=("jq" "rsync" "awk" "sed")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            log_pass "Command '$cmd' found"
        else
            log_fail "Command '$cmd' not found"
            missing_cmds+=("$cmd")
        fi
    done

    # Check asterisk (optional)
    if command -v asterisk &>/dev/null; then
        log_pass "Command 'asterisk' found"
        if [[ "$VERBOSE" == true ]]; then
            local version
            version=$(asterisk -V 2>/dev/null | head -1)
            log_verbose "$version"
        fi
    else
        log_warn "Command 'asterisk' not found (may be in custom path)"
    fi

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_info "Install missing commands: sudo apt install ${missing_cmds[*]}"
    fi

    return 0
}

# ==============================================================================
#    Directory Structure Checks
# ==============================================================================

check_directory_structure() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Directory Structure                  ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    local required_dirs=(
        "$INSTALL_BASE/bin"
        "$INSTALL_BASE/lib"
        "$INSTALL_BASE/util"
        "$INSTALL_BASE/sounds"
        "$INSTALL_BASE/backups"
    )

    local expected_sound_dirs=(
        "$INSTALL_BASE/sounds/_male"
        "$INSTALL_BASE/sounds/_female"
        "$INSTALL_BASE/sounds/_sndfx"
        "$INSTALL_BASE/sounds/ids"
        "$INSTALL_BASE/sounds/tails"
        "$INSTALL_BASE/sounds/rpt"
        "$INSTALL_BASE/sounds/wx"
        "$INSTALL_BASE/sounds/custom"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_pass "Directory exists: $dir"
            if [[ "$VERBOSE" == true ]]; then
                local count
                count=$(find "$dir" -type f 2>/dev/null | wc -l)
                log_verbose "Files: $count"
            fi
        else
            log_fail "Missing directory: $dir"
            ask_repair "Create directory $dir" \
                "mkdir -p '$dir' && chown asterisk:asterisk '$dir'"
        fi
    done

    for dir in "${expected_sound_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_verbose "Sound directory exists: $(basename "$dir")"
        else
            log_warn "Missing sound directory: $(basename "$dir")"
        fi
    done

    # Check symlinks
    local symlinks=(
        "/var/lib/asterisk/sounds:$INSTALL_BASE/sounds"
        "/usr/share/asterisk/sounds:$INSTALL_BASE/sounds"
    )

    for link_def in "${symlinks[@]}"; do
        IFS=':' read -r link target <<< "$link_def"
        if [[ -L "$link" ]]; then
            local actual_target
            actual_target=$(readlink -f "$link")
            if [[ "$actual_target" == "$target" ]]; then
                log_pass "Symlink correct: $link → $target"
            else
                log_fail "Symlink wrong target: $link → $actual_target (expected $target)"
                ask_repair "Fix symlink $link" \
                    "rm -f '$link' && ln -s '$target' '$link'"
            fi
        else
            if [[ -e "$link" ]]; then
                log_warn "Path exists but is not a symlink: $link"
            else
                log_warn "Symlink missing: $link → $target"
                ask_repair "Create symlink $link → $target" \
                    "ln -s '$target' '$link'"
            fi
        fi
    done
}

# ==============================================================================
#    Ownership and Permissions Checks
# ==============================================================================

check_ownership_permissions() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Ownership & Permissions              ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check /opt/app_rpt ownership
    if [[ -d "$INSTALL_BASE" ]]; then
        local owner
        owner=$(stat -c '%U:%G' "$INSTALL_BASE" 2>/dev/null || echo "unknown")
        if [[ "$owner" != "asterisk:asterisk" ]]; then
            log_fail "Incorrect ownership on $INSTALL_BASE: $owner"
            ask_repair "Fix ownership on $INSTALL_BASE (recursive)" \
                "chown -R asterisk:asterisk '$INSTALL_BASE'"
        else
            log_pass "Ownership correct on $INSTALL_BASE: $owner"
        fi

        # Check directory is readable/executable
        if [[ ! -r "$INSTALL_BASE" ]] || [[ ! -x "$INSTALL_BASE" ]]; then
            log_fail "$INSTALL_BASE is not readable/executable"
            ask_repair "Fix permissions on $INSTALL_BASE" \
                "chmod 755 '$INSTALL_BASE'"
        fi
    fi

    # Check critical Asterisk directories
    local asterisk_dirs=(
        "/var/lib/asterisk"
        "/var/log/asterisk"
        "/var/spool/asterisk"
        "/var/run/asterisk"
    )

    for dir in "${asterisk_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local owner
            owner=$(stat -c '%U:%G' "$dir" 2>/dev/null || echo "unknown")
            if [[ "$owner" != "asterisk:asterisk" ]]; then
                log_warn "Incorrect ownership on $dir: $owner (expected asterisk:asterisk)"
                ask_repair "Fix ownership on $dir (recursive)" \
                    "chown -R asterisk:asterisk '$dir'"
            else
                log_pass "Ownership correct on $dir"
            fi
        else
            log_verbose "Optional directory not present: $dir"
        fi
    done

    # Check /etc/asterisk ownership
    if [[ -d "/etc/asterisk" ]]; then
        local owner
        owner=$(stat -c '%U:%G' "/etc/asterisk" 2>/dev/null || echo "unknown")
        if [[ "$owner" != "asterisk:asterisk" ]] && [[ "$owner" != "root:asterisk" ]]; then
            log_warn "Unusual ownership on /etc/asterisk: $owner"
            log_info "  Typically should be asterisk:asterisk or root:asterisk"
            ask_repair "Fix ownership on /etc/asterisk (recursive)" \
                "chown -R asterisk:asterisk '/etc/asterisk'"
        else
            log_pass "Ownership acceptable on /etc/asterisk: $owner"
        fi

        # Check if asterisk user can read configs
        if ! sudo -u asterisk test -r "/etc/asterisk/asterisk.conf" 2>/dev/null; then
            log_fail "asterisk user cannot read /etc/asterisk/asterisk.conf"
            ask_repair "Fix /etc/asterisk permissions for asterisk user" \
                "chmod -R u+rX,g+rX /etc/asterisk && chown -R asterisk:asterisk /etc/asterisk"
        fi
    fi

    # Check sound directory symlinks are readable
    local sound_symlinks=(
        "/var/lib/asterisk/sounds"
        "/usr/share/asterisk/sounds"
    )

    for link in "${sound_symlinks[@]}"; do
        if [[ -L "$link" ]]; then
            if ! sudo -u asterisk test -r "$link" 2>/dev/null; then
                log_fail "asterisk user cannot read symlink: $link"
                local target
                target=$(readlink -f "$link")
                ask_repair "Fix permissions on sound symlink target" \
                    "chown -R asterisk:asterisk '$target' && chmod -R u+rX,g+rX '$target'"
            else
                log_pass "Sound symlink readable: $link"
            fi
        fi
    done
}

# ==============================================================================
#    Script File Checks
# ==============================================================================

check_script_files() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Script Files                         ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    local expected_scripts=(
        "common.sh" "asterisk.sh" "cmdparser.sh" "configkeeper.sh"
        "ctkeeper.sh" "ctwriter.sh" "datadumper.sh" "datekeeper.sh"
        "gpio.sh" "idkeeper.sh" "msgreader.sh" "msgwriter.sh"
        "restart.sh" "sayip.sh" "speaktext.sh" "statekeeper.sh"
        "system.sh" "tailkeeper.sh" "timekeeper.sh" "weatheralert.sh"
        "weatherkeeper.sh" "wireless.sh"
    )

    local missing_scripts=()

    for script in "${expected_scripts[@]}"; do
        local script_path="$INSTALL_BASE/bin/$script"

        if [[ ! -f "$script_path" ]]; then
            log_fail "Missing script: $script"
            missing_scripts+=("$script")
            continue
        fi

        # Check executable bit
        if [[ ! -x "$script_path" ]]; then
            log_fail "Script not executable: $script"
            ask_repair "Make $script executable" \
                "chmod 755 '$script_path'"
        else
            log_pass "Script exists and executable: $script"
        fi

        # Check ownership
        local owner
        owner=$(stat -c '%U:%G' "$script_path" 2>/dev/null || echo "unknown")
        if [[ "$owner" != "asterisk:asterisk" ]]; then
            log_warn "Incorrect ownership on $script: $owner (expected asterisk:asterisk)"
            ask_repair "Fix ownership on $script" \
                "chown asterisk:asterisk '$script_path'"
        else
            log_verbose "Ownership correct: $owner"
        fi

        # Check for %%BASEDIR%% placeholder (should be replaced)
        if grep -q '%%BASEDIR%%' "$script_path" 2>/dev/null; then
            log_fail "Placeholder not replaced in $script: %%BASEDIR%%"
            log_info "  This script was not properly installed"
        fi
    done

    # Special check for common.sh
    if [[ -f "$INSTALL_BASE/bin/common.sh" ]]; then
        if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh'" 2>/dev/null; then
            log_pass "common.sh can be sourced successfully"
        else
            log_fail "common.sh exists but cannot be sourced"
            log_info "  Check for syntax errors: bash -n $INSTALL_BASE/bin/common.sh"
        fi
    else
        log_fail "CRITICAL: common.sh missing (all scripts depend on it)"
        log_info "  Run upgrade.sh or reinstall to fix this issue"
    fi

    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_info "Missing ${#missing_scripts[@]} scripts"

        # If more than 3 scripts missing, offer to run upgrade.sh
        if [[ ${#missing_scripts[@]} -ge 3 ]]; then
            log_info "  Multiple scripts missing - suggesting full upgrade"

            # Try to find upgrade.sh
            local upgrade_script=""
            if [[ -f "$INSTALL_BASE/util/upgrade.sh" ]]; then
                upgrade_script="$INSTALL_BASE/util/upgrade.sh"
            elif [[ -f "./upgrade.sh" ]]; then
                upgrade_script="./upgrade.sh"
            fi

            if [[ -n "$upgrade_script" ]] && [[ "$CHECK_ONLY" != true ]]; then
                if ask_repair "Run upgrade.sh to restore all scripts" \
                    "sudo '$upgrade_script' --force"; then
                    log_fixed "Scripts restored via upgrade.sh"
                else
                    log_fail "Failed to run upgrade.sh"
                    log_info "  Try running: sudo $upgrade_script --force"
                fi
            else
                log_info "  Run: sudo upgrade.sh --force"
            fi
        fi
    fi

    # Check utility scripts
    echo ""
    log_info "Checking utility scripts..."
    local expected_utils=("install.sh" "upgrade.sh" "repair.sh" "uninstall.sh")
    local missing_utils=()

    for util in "${expected_utils[@]}"; do
        local util_path="$INSTALL_BASE/util/$util"

        if [[ ! -f "$util_path" ]]; then
            log_fail "Missing utility script: $util"
            missing_utils+=("$util")
        elif [[ ! -x "$util_path" ]]; then
            log_warn "Utility script not executable: $util"
            ask_repair "Make $util executable" \
                "chmod 755 '$util_path'"
        else
            log_pass "Utility script OK: $util"
        fi
    done

    if [[ ${#missing_utils[@]} -gt 0 ]]; then
        log_info "Missing ${#missing_utils[@]} utility scripts"
        log_info "  These can be restored by running upgrade.sh from the repository"

        # Offer to run upgrade.sh if it exists in common locations
        if [[ -f "$INSTALL_BASE/util/upgrade.sh" ]] && [[ "$AUTO_FIX" == true ]]; then
            log_info "Running upgrade.sh to restore utility scripts..."
            if sudo -u asterisk "$INSTALL_BASE/util/upgrade.sh" --force; then
                log_fixed "Utility scripts restored via upgrade.sh"
            else
                log_fail "Failed to restore utility scripts"
            fi
        fi
    fi

    return 0
}

# ==============================================================================
#    Configuration Checks
# ==============================================================================

check_configuration() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Configuration File                   ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check config.ini exists
    if [[ -f "$CONFIG_FILE" ]]; then
        log_pass "config.ini exists"
        if [[ "$VERBOSE" == true ]]; then
            local size
            size=$(stat -c '%s' "$CONFIG_FILE" 2>/dev/null)
            log_verbose "Size: $size bytes"
            local modified
            modified=$(stat -c '%y' "$CONFIG_FILE" 2>/dev/null | cut -d'.' -f1)
            log_verbose "Modified: $modified"
        fi
    else
        log_fail "config.ini not found: $CONFIG_FILE"
        log_info "  Cannot proceed without configuration"
        return 1
    fi

    # Check config.ini can be sourced
    if bash -c "set +u; source '$CONFIG_FILE'" 2>/dev/null; then
        log_pass "config.ini has valid syntax"
    else
        log_fail "config.ini has syntax errors"
        log_info "  Check for typos, unmatched quotes, etc."
        return 1
    fi

    # Load config and check required variables
    set +u
    source "$CONFIG_FILE" || return 1

    local required_vars=(
        "MYNODE" "NWSZONE" "BASEDIR" "BINDIR" "LIBDIR" "SOUNDS"
        "RPTCONF" "SNDMALE" "SNDFEMALE" "SNDRPT" "SNDID" "SNDTAIL"
    )

    local v2_required_vars=(
        "landevice" "wlandevice" "vpndevice"
    )

    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_pass "Config variable set: $var"
            log_verbose "  $var=${!var}"
        else
            log_fail "Config variable missing or empty: $var"
            missing_vars+=("$var")
        fi
    done

    # Check v2.0 specific variables
    for var in "${v2_required_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_pass "Network variable set: $var=${!var}"
            # Validate interface exists
            if ip link show "${!var}" &>/dev/null; then
                log_verbose "  Interface ${!var} exists"
            else
                log_warn "  Interface ${!var} not found on system"
            fi
        else
            log_fail "Network variable missing: $var (required in v2.0+)"
            log_info "  Add to config.ini or run upgrade.sh to migrate"
            missing_vars+=("$var")
        fi
    done

    # Validate MYNODE format
    if [[ "${MYNODE:-}" =~ ^[0-9]{5,6}$ ]]; then
        log_pass "MYNODE format valid: $MYNODE"
    else
        log_warn "MYNODE format unusual: ${MYNODE:-empty}"
        log_info "  Expected 5-6 digit number"
    fi

    # Check paths are valid
    local path_vars=("BASEDIR" "BINDIR" "LIBDIR" "SOUNDS" "RPTCONF")
    for var in "${path_vars[@]}"; do
        if [[ -n "${!var:-}" ]] && [[ -e "${!var}" ]]; then
            log_verbose "Path exists: $var=${!var}"
        elif [[ -n "${!var:-}" ]]; then
            log_warn "Path not found: $var=${!var}"
        fi
    done

    set -u

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_info "Missing ${#missing_vars[@]} required variables"
    fi

    return 0
}

# ==============================================================================
#    Asterisk Configuration Checks
# ==============================================================================

check_asterisk_config() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Asterisk Configuration               ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check rpt.conf exists
    if [[ -f /etc/asterisk/rpt.conf ]]; then
        log_pass "rpt.conf exists"
        if [[ "$VERBOSE" == true ]]; then
            local size
            size=$(stat -c '%s' /etc/asterisk/rpt.conf 2>/dev/null)
            log_verbose "Size: $size bytes"
        fi
    else
        log_fail "rpt.conf not found: /etc/asterisk/rpt.conf"
    fi

    # Check custom extensions
    if [[ -f /etc/asterisk/custom/extensions.conf ]]; then
        log_pass "Custom extensions.conf exists"
    else
        log_warn "Custom extensions not found (may not be required)"
    fi

    # Check Asterisk is running
    if command -v asterisk &>/dev/null; then
        # Run asterisk commands as asterisk user (Asterisk runs as asterisk, not root)
        local ast_cmd="asterisk"
        if [[ $EUID -eq 0 ]]; then
            ast_cmd="sudo -u asterisk asterisk"
        fi

        if $ast_cmd -rx "core show version" &>/dev/null; then
            log_pass "Asterisk is running and responding"
            if [[ "$VERBOSE" == true ]]; then
                local version
                version=$($ast_cmd -rx 'core show version' 2>/dev/null | head -1)
                log_verbose "$version"
            fi

            # Test app_rpt is loaded
            if $ast_cmd -rx "module show like app_rpt" 2>/dev/null | grep -q "app_rpt"; then
                log_pass "app_rpt module loaded"
            else
                log_warn "app_rpt module not loaded"
            fi

            # Check if node is configured
            set +u
            source "$CONFIG_FILE" 2>/dev/null
            if [[ -n "${MYNODE:-}" ]]; then
                if $ast_cmd -rx "rpt showvars ${MYNODE}" &>/dev/null 2>&1; then
                    log_pass "Node ${MYNODE} configured in Asterisk"
                else
                    log_warn "Node ${MYNODE} not found in Asterisk config"
                fi
            fi
            set -u
        else
            log_warn "Asterisk not running"
            log_info "  Start with: systemctl start asterisk"
        fi
    else
        log_warn "Asterisk command not found"
    fi
}

# ==============================================================================
#    Cron Job Checks
# ==============================================================================

check_cron_jobs() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Cron Jobs                            ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check if asterisk user has a crontab
    if crontab -u asterisk -l &>/dev/null 2>&1; then
        log_pass "asterisk user has crontab"
        local job_count
        job_count=$(crontab -u asterisk -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l)
        log_info "  $job_count cron job(s) configured"

        if [[ $job_count -eq $EXPECTED_CRON_JOBS ]]; then
            log_pass "Expected number of cron jobs ($EXPECTED_CRON_JOBS)"
        else
            log_warn "Unexpected job count (expected $EXPECTED_CRON_JOBS, found $job_count)"
        fi
    else
        log_fail "asterisk user has no crontab"
        log_info "  Cron jobs are needed for automatic ID rotation, time announcements, weather alerts, etc."

        # Offer to create basic crontab if scripts exist
        if [[ "$CHECK_ONLY" != true ]] && [[ -d "$INSTALL_BASE/bin" ]]; then
            if ask_repair "Create crontab with standard app_rpt__ultra jobs" \
                "cat > /tmp/crontab.$$ <<'CRON'
*/5  * * * * $INSTALL_BASE/bin/idkeeper.sh
*/15 * * * * $INSTALL_BASE/bin/tailkeeper.sh
*/30 * * * * $INSTALL_BASE/bin/timekeeper.sh
*/5  * * * * $INSTALL_BASE/bin/weatheralert.sh
0    3 * * * $INSTALL_BASE/bin/weatherkeeper.sh
0    0 * * * $INSTALL_BASE/bin/datekeeper.sh
*/30 * * * * $INSTALL_BASE/bin/datadumper.sh
CRON
crontab -u asterisk /tmp/crontab.$$
rm -f /tmp/crontab.$$"; then
                log_fixed "Crontab created for asterisk user"
            else
                log_fail "Failed to create crontab"
                log_info "  Try running: sudo install.sh to configure cron jobs"
            fi
        else
            log_info "  Run: sudo install.sh to configure cron jobs"
        fi
        return 1
    fi

    # Check expected jobs exist
    local expected_jobs=(
        "idkeeper.sh"
        "tailkeeper.sh"
        "timekeeper.sh"
        "weatheralert.sh"
        "weatherkeeper.sh"
        "datekeeper.sh"
        "datadumper.sh"
    )

    local crontab_content
    crontab_content=$(crontab -u asterisk -l 2>/dev/null)

    for job in "${expected_jobs[@]}"; do
        if echo "$crontab_content" | grep -q "$job"; then
            log_pass "Cron job exists: $job"
            if [[ "$VERBOSE" == true ]]; then
                echo "$crontab_content" | grep "$job" | sed 's/^/  /'
            fi

            # Verify script exists
            if [[ ! -f "$INSTALL_BASE/bin/$job" ]]; then
                log_warn "  Script file missing for cron job: $job"
            fi
        else
            log_fail "Cron job missing: $job"
        fi
    done

    # Check for correct paths
    if echo "$crontab_content" | grep -v '^#' | grep -q '/opt/app_rpt'; then
        log_verbose "Cron jobs use correct path (/opt/app_rpt)"
    fi

    return 0
}

# ==============================================================================
#    Sound File Checks
# ==============================================================================

check_sound_files() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Sound Files                          ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Check vocabulary exists
    if [[ -f "$INSTALL_BASE/lib/vocabulary.txt" ]]; then
        local word_count
        word_count=$(wc -l < "$INSTALL_BASE/lib/vocabulary.txt" 2>/dev/null)
        log_pass "Vocabulary file exists: $word_count words"
    else
        log_fail "vocabulary.txt missing"
    fi

    # Check for conflicting Asterisk en directory
    if [[ -d "/var/lib/asterisk/sounds/en" ]]; then
        log_fail "Conflicting directory found: /var/lib/asterisk/sounds/en"
        log_info "   This conflicts with app_rpt__ultra's internal vocabulary"
        if [[ "$CHECK_ONLY" != true ]]; then
            if ask_repair "Remove /var/lib/asterisk/sounds/en directory?"; then
                if rm -rf /var/lib/asterisk/sounds/en 2>/dev/null; then
                    log_fixed "Removed conflicting en directory"
                else
                    log_fail "Failed to remove en directory"
                fi
            fi
        fi
    else
        log_pass "No conflicting en directory"
    fi

    # Check male/female voice directories
    if [[ -d "$INSTALL_BASE/sounds/_male" ]]; then
        local male_count
        male_count=$(find "$INSTALL_BASE/sounds/_male" -name "*.ulaw" 2>/dev/null | wc -l)
        if [[ $male_count -gt 0 ]]; then
            log_pass "Male voice files: $male_count files"
        else
            log_warn "No male voice files found"
        fi
    else
        log_warn "Male voice directory missing"
    fi

    if [[ -d "$INSTALL_BASE/sounds/_female" ]]; then
        local female_count
        female_count=$(find "$INSTALL_BASE/sounds/_female" -name "*.ulaw" 2>/dev/null | wc -l)
        if [[ $female_count -gt 0 ]]; then
            log_pass "Female voice files: $female_count files"
        else
            log_warn "No female voice files found"
        fi
    else
        log_warn "Female voice directory missing"
    fi

    # Check critical system sounds
    local critical_sounds=(
        "rpt/programming_complete"
        "rpt/program_error"
        "rpt/empty"
    )

    for sound in "${critical_sounds[@]}"; do
        if [[ -f "$INSTALL_BASE/sounds/${sound}.ulaw" ]]; then
            log_verbose "Critical sound exists: $sound"
        else
            log_warn "Missing critical sound: $sound"
        fi
    done

    # Check voice ID symlink exists (created by idkeeper.sh)
    set +u
    source "$CONFIG_FILE" 2>/dev/null
    if [[ -n "${MYNODE:-}" ]]; then
        if [[ -L "$INSTALL_BASE/sounds/voice_id.ulaw" ]]; then
            local target
            target=$(readlink "$INSTALL_BASE/sounds/voice_id.ulaw")
            log_pass "Voice ID symlink exists: $(basename "$target")"
        elif [[ -f "$INSTALL_BASE/sounds/voice_id.ulaw" ]]; then
            log_warn "Voice ID exists but is not a symlink (should be managed by idkeeper.sh)"
        else
            log_warn "Voice ID symlink missing (will be created by idkeeper.sh cron job)"
        fi
    fi
    set -u
}

# ==============================================================================
#    Log File Checks
# ==============================================================================

check_log_file() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Log File                             ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    if [[ -f "$LOG_FILE" ]]; then
        log_pass "Log file exists: $LOG_FILE"
        if [[ "$VERBOSE" == true ]]; then
            local size
            size=$(stat -c '%s' "$LOG_FILE" 2>/dev/null)
            log_verbose "Size: $size bytes"
            local modified
            modified=$(stat -c '%y' "$LOG_FILE" 2>/dev/null | cut -d'.' -f1)
            log_verbose "Modified: $modified"
        fi

        # Check if writable by asterisk user
        if sudo -u asterisk test -w "$LOG_FILE" 2>/dev/null; then
            log_pass "Log file writable by asterisk user"
        else
            log_fail "Log file not writable by asterisk user"
            ask_repair "Fix log file permissions" \
                "chmod 664 '$LOG_FILE' && chown asterisk:asterisk '$LOG_FILE'"
        fi

        # Check for recent errors
        if [[ -s "$LOG_FILE" ]]; then
            local error_count
            error_count=$(grep "ERROR" "$LOG_FILE" 2>/dev/null | tail -100 | wc -l)
            if [[ $error_count -gt 0 ]]; then
                log_warn "Found $error_count recent errors in log"
                if [[ "$VERBOSE" == true ]]; then
                    echo "  Recent errors:"
                    grep "ERROR" "$LOG_FILE" | tail -5 | sed 's/^/    /'
                fi
            else
                log_verbose "No errors in recent log entries"
            fi
        fi
    else
        log_warn "Log file does not exist: $LOG_FILE"
        ask_repair "Create log file" \
            "touch '$LOG_FILE' && chmod 664 '$LOG_FILE' && chown asterisk:asterisk '$LOG_FILE'"
    fi
}

# ==============================================================================
#    Runtime Tests
# ==============================================================================

check_runtime_tests() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Runtime Tests                        ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    # Test common.sh can be sourced
    if [[ -f "$INSTALL_BASE/bin/common.sh" ]]; then
        if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh' 2>&1" &>/dev/null; then
            log_pass "common.sh sources without errors"
        else
            log_fail "common.sh failed to source"
            log_info "  Check syntax: bash -n $INSTALL_BASE/bin/common.sh"
        fi
    else
        log_warn "common.sh not found, skipping runtime tests"
        return 0
    fi

    # Test config validation function (if common.sh has it)
    if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh' && declare -f validate_config &>/dev/null" 2>/dev/null; then
        if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh' && validate_config" 2>/dev/null; then
            log_pass "Config validation function passes"
        else
            log_fail "Config validation function failed"
            log_info "  Check required variables in config.ini"
        fi
    else
        log_verbose "validate_config function not available (older version?)"
    fi
}

# ==============================================================================
#    Summary Report
# ==============================================================================

generate_summary() {
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  Health Check Summary                 ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    local total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

    echo "Total Checks: $total_checks"
    echo -e "  ${GREEN}Passed:${NC}   $CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $CHECKS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $CHECKS_WARNING"

    if [[ $FIXES_APPLIED -gt 0 ]]; then
        echo -e "  ${CYAN}Fixed:${NC}    $FIXES_APPLIED"
    fi

    echo ""

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ System appears healthy!${NC}"
        return 0
    elif [[ $CHECKS_FAILED -le 3 ]]; then
        echo -e "${YELLOW}⚠ Minor issues detected${NC}"
        echo "  Consider running repair actions above"
        return 1
    else
        echo -e "${RED}✗ Significant issues detected${NC}"
        echo "  Run with --auto-fix to repair automatically"
        echo "  Or run upgrade.sh if major files are missing"
        return 2
    fi
}

# ==============================================================================
#    Command Line Parsing
# ==============================================================================

# Parse command line options
CHECK_ONLY=false
AUTO_FIX=false
VERBOSE=false
REPORT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-only) CHECK_ONLY=true; shift ;;
        --auto-fix) AUTO_FIX=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --report) REPORT_FILE="$2"; shift 2 ;;
        --help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# ==============================================================================
#    Main Execution
# ==============================================================================

main() {
    # Banner
    echo ""
    echo "╔═══════════════════════════════════════╗"
    echo "║  app_rpt__ultra System Repair Tool    ║"
    echo "║  Version $SCRIPT_VERSION                        ║"
    echo "╚═══════════════════════════════════════╝"
    echo ""

    if [[ "$CHECK_ONLY" == true ]]; then
        log_info "CHECK-ONLY MODE - No repairs will be performed"
    elif [[ "$AUTO_FIX" == true ]]; then
        log_info "AUTO-FIX MODE - Will repair all issues automatically"
    fi

    if [[ -n "$REPORT_FILE" ]]; then
        log_info "Saving report to: $REPORT_FILE"
        echo "app_rpt__ultra System Health Report" > "$REPORT_FILE"
        echo "Generated: $(date)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    # Run all check categories
    check_system_basics
    check_directory_structure
    check_ownership_permissions
    check_script_files
    check_configuration
    check_asterisk_config
    check_cron_jobs
    check_sound_files
    check_log_file
    check_runtime_tests

    # Generate summary
    generate_summary
    local exit_code=$?

    if [[ -n "$REPORT_FILE" ]]; then
        echo "" >> "$REPORT_FILE"
        echo "Check Summary:" >> "$REPORT_FILE"
        echo "  Passed: $CHECKS_PASSED" >> "$REPORT_FILE"
        echo "  Failed: $CHECKS_FAILED" >> "$REPORT_FILE"
        echo "  Warnings: $CHECKS_WARNING" >> "$REPORT_FILE"
        echo "  Fixes Applied: $FIXES_APPLIED" >> "$REPORT_FILE"
        log_info "Report saved to: $REPORT_FILE"
    fi

    exit $exit_code
}

# Execute main
main "$@"
