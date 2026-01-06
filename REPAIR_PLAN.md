# Implementation Plan: repair.sh

## Overview

A comprehensive system health check and repair tool for app_rpt__ultra installations. Diagnoses common problems, validates configuration, checks file integrity, and repairs issues automatically or with user confirmation.

---

## Usage

```bash
sudo ./repair.sh [options]

Options:
  --check-only       Only check for problems, don't fix anything
  --auto-fix         Automatically fix all issues without prompting
  --verbose          Show detailed output for all checks
  --report FILE      Save detailed report to FILE
  --help             Show this help message

Examples:
  sudo ./repair.sh                    # Interactive repair with prompts
  sudo ./repair.sh --check-only       # Health check only
  sudo ./repair.sh --auto-fix         # Fix everything automatically
  sudo ./repair.sh --verbose --report /tmp/health.txt
```

---

## Script Structure

### 1. Initialization (Lines 1-100)

```bash
#!/usr/bin/env bash
set -euo pipefail

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

# Counters for reporting
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0
FIXES_APPLIED=0

# Logging functions
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
```

### 2. Repair Functions (Lines 101-200)

```bash
ask_repair() {
    local question="$1"
    local fix_function="$2"

    if [[ "$CHECK_ONLY" == true ]]; then
        return 1  # Don't fix in check-only mode
    fi

    if [[ "$AUTO_FIX" == true ]]; then
        log_info "Auto-fixing: $question"
        $fix_function
        return 0
    fi

    read -p "$(echo -e "${YELLOW}Repair:${NC} $question? [y/N] ")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $fix_function
        return 0
    fi
    return 1
}

create_repair_backup() {
    local backup_dir="$INSTALL_BASE/backups/repair_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    log_info "Created repair backup: $backup_dir"
    echo "$backup_dir"
}
```

### 3. System Checks (Lines 201-350)

```bash
check_system_basics() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  System Prerequisites                  ║"
    echo "╚════════════════════════════════════════╝"
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
        log_verbose "$(du -sh $INSTALL_BASE 2>/dev/null | awk '{print "Size: " $1}')"
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
    local missing_optional=()

    for group in "${required_groups[@]}"; do
        if id -nG asterisk | grep -qw "$group"; then
            log_pass "asterisk user in $group group"
        else
            log_fail "asterisk user not in $group group"
            missing_required+=("$group")
        fi
    done

    for group in "${optional_groups[@]}"; do
        if id -nG asterisk | grep -qw "$group"; then
            log_verbose "asterisk user in $group group (optional)"
        else
            log_warn "asterisk user not in $group group (may be needed)"
            missing_optional+=("$group")
        fi
    done

    # Offer to fix group membership
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        ask_repair "Add asterisk to required groups: ${missing_required[*]}" \
            "fix_user_groups"
    fi

    # Check required commands
    local required_cmds=("jq" "asterisk" "rsync" "awk" "sed")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            log_pass "Command '$cmd' found"
            if [[ "$cmd" == "asterisk" ]]; then
                log_verbose "$(asterisk -V 2>/dev/null || echo 'Version check failed')"
            fi
        else
            log_fail "Command '$cmd' not found"
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_info "Install missing commands: sudo apt install ${missing_cmds[*]}"
    fi

    return 0
}

fix_user_groups() {
    log_info "Adding asterisk user to required groups..."
    usermod -a -G dialout,audio,plugdev asterisk
    log_fixed "asterisk user added to groups"
}
```

### 4. File Structure Checks (Lines 351-550)

```bash
check_directory_structure() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Directory Structure                   ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    local required_dirs=(
        "$INSTALL_BASE/bin"
        "$INSTALL_BASE/lib"
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
            log_verbose "Files: $(find "$dir" -type f 2>/dev/null | wc -l)"
        else
            log_fail "Missing directory: $dir"
            ask_repair "Create directory $dir" "mkdir -p '$dir' && chown asterisk:asterisk '$dir'"
        fi
    done

    for dir in "${expected_sound_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_verbose "Sound directory exists: $dir"
        else
            log_warn "Missing sound directory: $dir"
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
                ask_repair "Fix symlink $link" "rm -f '$link' && ln -s '$target' '$link'"
            fi
        else
            log_warn "Symlink missing: $link → $target"
            if [[ -e "$link" ]]; then
                log_warn "  Path exists but is not a symlink"
            else
                ask_repair "Create symlink $link → $target" "ln -s '$target' '$link'"
            fi
        fi
    done
}

check_script_files() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Script Files                          ║"
    echo "╚════════════════════════════════════════╝"
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
    local permission_issues=()

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
            permission_issues+=("$script_path")
            ask_repair "Make $script executable" "chmod 755 '$script_path'"
        else
            log_pass "Script exists and executable: $script"
        fi

        # Check ownership
        local owner
        owner=$(stat -c '%U:%G' "$script_path")
        if [[ "$owner" != "asterisk:asterisk" ]]; then
            log_warn "Incorrect ownership on $script: $owner (expected asterisk:asterisk)"
            ask_repair "Fix ownership on $script" "chown asterisk:asterisk '$script_path'"
        else
            log_verbose "Ownership correct: $owner"
        fi

        # Check for %%BASEDIR%% placeholder (should be replaced)
        if grep -q '%%BASEDIR%%' "$script_path"; then
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

    return 0
}
```

### 5. Configuration Checks (Lines 551-750)

```bash
check_configuration() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Configuration File                    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check config.ini exists
    if [[ -f "$CONFIG_FILE" ]]; then
        log_pass "config.ini exists"
        log_verbose "Size: $(stat -c '%s' "$CONFIG_FILE") bytes"
        log_verbose "Modified: $(stat -c '%y' "$CONFIG_FILE")"
    else
        log_fail "config.ini not found: $CONFIG_FILE"
        log_info "  Cannot proceed without configuration"
        return 1
    fi

    # Check config.ini can be sourced
    if bash -c "source '$CONFIG_FILE'" 2>/dev/null; then
        log_pass "config.ini has valid syntax"
    else
        log_fail "config.ini has syntax errors"
        log_info "  Check for typos, unmatched quotes, etc."
        return 1
    fi

    # Load config and check required variables
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

    return 0
}

check_asterisk_config() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Asterisk Configuration                ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check rpt.conf exists
    if [[ -f /etc/asterisk/rpt.conf ]]; then
        log_pass "rpt.conf exists"
        log_verbose "Size: $(stat -c '%s' /etc/asterisk/rpt.conf) bytes"
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
        if asterisk -rx "core show version" &>/dev/null; then
            log_pass "Asterisk is running and responding"
            log_verbose "$(asterisk -rx 'core show version' 2>/dev/null | head -1)"

            # Test app_rpt is loaded
            if asterisk -rx "module show like app_rpt" 2>/dev/null | grep -q "app_rpt"; then
                log_pass "app_rpt module loaded"
            else
                log_warn "app_rpt module not loaded"
            fi

            # Check if node is configured
            source "$CONFIG_FILE" 2>/dev/null
            if asterisk -rx "rpt showvars ${MYNODE:-0}" &>/dev/null; then
                log_pass "Node ${MYNODE:-0} configured in Asterisk"
            else
                log_warn "Node ${MYNODE:-0} not found in Asterisk config"
            fi
        else
            log_warn "Asterisk not running"
            log_info "  Start with: systemctl start asterisk"
        fi
    else
        log_warn "Asterisk command not found"
    fi
}
```

### 6. Cron Job Checks (Lines 751-900)

```bash
check_cron_jobs() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Cron Jobs                             ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check if asterisk user has a crontab
    if crontab -u asterisk -l &>/dev/null; then
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
        log_info "  Run install.sh to configure cron jobs"
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

    # Check for dead/old jobs pointing to wrong paths
    if echo "$crontab_content" | grep -v '^#' | grep -q '/opt/app_rpt' ; then
        log_verbose "Cron jobs use correct path (/opt/app_rpt)"
    fi

    return 0
}
```

### 7. Sound File Checks (Lines 901-1000)

```bash
check_sound_files() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Sound Files                           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check vocabulary exists
    if [[ -f "$INSTALL_BASE/lib/vocabulary.txt" ]]; then
        local word_count
        word_count=$(wc -l < "$INSTALL_BASE/lib/vocabulary.txt")
        log_pass "Vocabulary file exists: $word_count words"
    else
        log_fail "vocabulary.txt missing"
    fi

    # Check male/female voice directories
    local male_count female_count
    male_count=$(find "$INSTALL_BASE/sounds/_male" -name "*.ulaw" 2>/dev/null | wc -l)
    female_count=$(find "$INSTALL_BASE/sounds/_female" -name "*.ulaw" 2>/dev/null | wc -l)

    if [[ $male_count -gt 0 ]]; then
        log_pass "Male voice files: $male_count files"
    else
        log_warn "No male voice files found"
    fi

    if [[ $female_count -gt 0 ]]; then
        log_pass "Female voice files: $female_count files"
    else
        log_warn "No female voice files found"
    fi

    # Check critical system sounds
    local critical_sounds=(
        "rpt/program_complete"
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

    # Check voice ID exists
    source "$CONFIG_FILE" 2>/dev/null
    if [[ -n "${MYNODE:-}" ]]; then
        if [[ -f "$INSTALL_BASE/sounds/ids/voice_id.ulaw" ]]; then
            log_pass "Voice ID file exists"
        else
            log_warn "Voice ID file missing (may not be generated yet)"
        fi
    fi
}
```

### 8. Log File Checks (Lines 1001-1050)

```bash
check_log_file() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Log File                              ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    if [[ -f "$LOG_FILE" ]]; then
        log_pass "Log file exists: $LOG_FILE"
        log_verbose "Size: $(stat -c '%s' "$LOG_FILE") bytes"
        log_verbose "Modified: $(stat -c '%y' "$LOG_FILE")"

        # Check if writable by asterisk user
        if sudo -u asterisk test -w "$LOG_FILE"; then
            log_pass "Log file writable by asterisk user"
        else
            log_fail "Log file not writable by asterisk user"
            ask_repair "Fix log file permissions" "chmod 664 '$LOG_FILE' && chown asterisk:asterisk '$LOG_FILE'"
        fi

        # Check for recent errors
        if [[ -s "$LOG_FILE" ]]; then
            local error_count
            error_count=$(grep -c "ERROR" "$LOG_FILE" 2>/dev/null | tail -100 || echo 0)
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
        ask_repair "Create log file" "touch '$LOG_FILE' && chmod 664 '$LOG_FILE' && chown asterisk:asterisk '$LOG_FILE'"
    fi
}
```

### 9. Runtime Tests (Lines 1051-1150)

```bash
check_runtime_tests() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Runtime Tests                         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Test common.sh can be sourced
    if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh' && echo 'Success'" &>/dev/null; then
        log_pass "common.sh sources without errors"
    else
        log_fail "common.sh failed to source"
        log_info "  Check syntax: bash -n $INSTALL_BASE/bin/common.sh"
    fi

    # Test a simple script execution
    if sudo -u asterisk "$INSTALL_BASE/bin/system.sh" test &>/dev/null; then
        log_pass "Scripts can execute as asterisk user"
    else
        log_verbose "Script test returned non-zero (may be expected)"
    fi

    # Test config validation function
    if sudo -u asterisk bash -c "source '$INSTALL_BASE/bin/common.sh' && validate_config" 2>/dev/null; then
        log_pass "Config validation passes"
    else
        log_fail "Config validation failed"
        log_info "  Check required variables in config.ini"
    fi
}
```

### 10. Report Generation & Main (Lines 1151-1350)

```bash
generate_summary() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Health Check Summary                  ║"
    echo "╚════════════════════════════════════════╝"
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

show_help() {
    cat <<EOF
app_rpt__ultra System Repair Tool v$SCRIPT_VERSION

Usage: sudo $0 [options]

Options:
  --check-only       Only check for problems, don't fix anything
  --auto-fix         Automatically fix all issues without prompting
  --verbose          Show detailed output for all checks
  --report FILE      Save detailed report to FILE
  --help             Show this help message

Examples:
  sudo $0                    # Interactive repair with prompts
  sudo $0 --check-only       # Health check only, no repairs
  sudo $0 --auto-fix         # Fix everything automatically
  sudo $0 --verbose --report /tmp/health.txt

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

For more information, see the documentation at:
https://github.com/yourusername/app_rpt__ultra

EOF
}

main() {
    # Banner
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  app_rpt__ultra System Repair Tool    ║"
    echo "║  Version $SCRIPT_VERSION                       ║"
    echo "╚════════════════════════════════════════╝"
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
```

---

## Check Categories Summary

### 1. System Prerequisites (10-15 checks)
- Root permission
- Installation directory exists
- asterisk user exists
- asterisk user group memberships (dialout, audio, sudo, plugdev)
- Required commands (jq, asterisk, rsync, awk, sed)
- Asterisk version

### 2. Directory Structure (15-20 checks)
- Required directories (bin, lib, sounds, backups)
- Sound subdirectories (8 directories)
- Symlinks to Asterisk sound directories (2)
- Directory permissions

### 3. Script Files (25-30 checks)
- All 22 scripts present
- Scripts are executable
- Scripts have correct ownership (asterisk:asterisk)
- No %%BASEDIR%% placeholders remaining
- common.sh can be sourced
- Syntax validation

### 4. Configuration (15-20 checks)
- config.ini exists
- config.ini has valid syntax
- Required variables present (12+ vars)
- Network interface variables (v2.0+)
- MYNODE format validation
- Path variables point to real locations

### 5. Asterisk Configuration (8-10 checks)
- rpt.conf exists
- Custom extensions exist
- Asterisk is running
- app_rpt module loaded
- Node configured in Asterisk

### 6. Cron Jobs (8-10 checks)
- asterisk user has crontab
- Expected number of jobs (7)
- Each expected job exists
- Scripts referenced by cron exist
- Cron paths are correct

### 7. Sound Files (10-12 checks)
- vocabulary.txt exists
- Male voice files present
- Female voice files present
- Critical system sounds exist
- Voice ID exists

### 8. Log File (4-5 checks)
- Log file exists
- Log file writable by asterisk
- Recent error check
- Log file not growing too large

### 9. Runtime Tests (3-5 checks)
- common.sh sources successfully
- Scripts can execute as asterisk user
- Config validation function works

**Total: ~100-130 checks**

---

## Repair Actions

### Automatic Repairs (Safe)
- ✅ Fix file permissions (chmod/chown)
- ✅ Create missing directories
- ✅ Create missing log file
- ✅ Fix symlinks
- ✅ Add asterisk to groups

### Manual Repairs (Require Confirmation)
- ⚠️ Reinstall missing scripts
- ⚠️ Regenerate config.ini
- ⚠️ Restore from backup
- ⚠️ Reinstall cron jobs

### Cannot Repair (Refer to Other Tools)
- ❌ Missing installation → Run install.sh
- ❌ Major file corruption → Run upgrade.sh
- ❌ Asterisk not installed → Install ASL3
- ❌ Syntax errors in scripts → Manual edit or reinstall

---

## Exit Codes

- `0` - All checks passed (system healthy)
- `1` - Minor issues (warnings only)
- `2` - Significant issues (some failures)
- `3` - Critical error (cannot proceed with checks)

---

## Future Enhancements

1. **Interactive TUI** - ncurses-based interface for better UX
2. **Scheduled health checks** - Add to cron for daily checks
3. **Email notifications** - Send health report to admin
4. **Performance checks** - Monitor CPU, memory, disk usage
5. **Database checks** - Validate Asterisk SQLite databases
6. **Network connectivity** - Test AllStarLink network access
7. **Backup validation** - Check backups are restorable
8. **Security audit** - Check file permissions, sudoers, etc.
9. **Benchmark tests** - Measure system performance
10. **Self-update** - Download latest version of repair.sh

---

## Estimated Script Size

**Approximately 1300-1400 lines** including:
- 100 lines: Header, initialization, option parsing
- 150 lines: Logging and repair helper functions
- 200 lines: System prerequisites checks
- 200 lines: File structure and script checks
- 200 lines: Configuration checks
- 150 lines: Asterisk and cron checks
- 100 lines: Sound file and log checks
- 50 lines: Runtime tests
- 100 lines: Summary and reporting
- 50 lines: Help text and main execution
- 100 lines: Comments and documentation
