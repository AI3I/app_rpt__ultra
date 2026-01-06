# Upgrade Analysis: Live System vs Repository (v2.0.1)

**Analysis Date:** 2026-01-06
**Live System:** ai3i@repeater.ai3i.net
**Repository:** /home/jdlewis/GitHub/app_rpt__ultra
**Installation Path:** /opt/app_rpt

---

## Executive Summary

**All 21 scripts have been modified** in the repository, and **1 new critical file (common.sh)** has been added. This represents a **major refactoring** that changes how scripts load configuration and handle errors. An upgrade path must be carefully designed to prevent breaking the running system.

### Critical Breaking Changes

1. ✅ **NEW FILE: common.sh** - All scripts now depend on this shared initialization library
2. ✅ **Configuration Loading Changed** - Scripts now source `common.sh` instead of directly sourcing `config.ini`
3. ✅ **Missing Config Variables** - Live system is missing network interface variables (`landevice`, `wlandevice`, `vpndevice`)
4. ✅ **Bash Safety Settings** - New scripts use `set -euo pipefail` (will exit on undefined variables)

---

## File Comparison

### Script Changes (Live → Repo)

| Script | Live (bytes) | Repo (bytes) | Change | Notes |
|--------|--------------|--------------|--------|-------|
| **common.sh** | ❌ N/A | ✅ 5,207 | **NEW** | **CRITICAL: All scripts depend on this** |
| asterisk.sh | 1,540 | 1,513 | -27 | Minor refactoring |
| cmdparser.sh | 1,651 | 1,686 | +35 | Minor changes |
| configkeeper.sh | 2,463 | 2,026 | -437 | Refactored with common.sh |
| ctkeeper.sh | 1,657 | 1,651 | -6 | Minor changes |
| ctwriter.sh | 3,003 | 3,099 | +96 | Enhanced |
| datadumper.sh | 1,462 | 1,439 | -23 | Minor refactoring |
| datekeeper.sh | 1,315 | 1,352 | +37 | Minor changes |
| gpio.sh | 2,949 | 2,917 | -32 | Minor refactoring |
| idkeeper.sh | 2,006 | 2,103 | +97 | Enhanced |
| msgreader.sh | 1,110 | 1,335 | +225 | Enhanced |
| msgwriter.sh | 2,758 | 2,949 | +191 | Enhanced |
| restart.sh | 1,957 | 2,278 | +321 | Enhanced |
| **sayip.sh** | 1,391 | 2,328 | **+937** | **MAJOR: Bug fix + header** |
| speaktext.sh | 2,382 | 2,744 | +362 | Enhanced |
| statekeeper.sh | 9,569 | 10,067 | +498 | Enhanced |
| system.sh | 1,402 | 1,351 | -51 | Minor refactoring |
| tailkeeper.sh | 2,817 | 2,896 | +79 | Enhanced |
| **timekeeper.sh** | 3,975 | 2,829 | **-1,146** | **MAJOR: Refactored** |
| weatheralert.sh | 3,394 | 3,517 | +123 | Enhanced |
| weatherkeeper.sh | 10,177 | 9,663 | -514 | Refactored |
| wireless.sh | 1,947 | 1,888 | -59 | Minor refactoring |

**Total:** Live: 69,477 bytes (21 files) → Repo: 85,834 bytes (22 files) = **+16,357 bytes (+23.5%)**

---

## Configuration File Changes

### config.ini Comparison

**Live:** 174 lines (6,239 bytes)
**Repo:** 182 lines (template with placeholders)

#### Missing Variables on Live System

The repository version includes these NEW variables that don't exist on the live system:

```bash
# Network interface device names (for sayip.sh)
landevice=eth0
wlandevice=wlan0
vpndevice=tun0
```

**⚠️ CRITICAL BUG:** The live `sayip.sh` script uses these variables (`$landevice`, `$wlandevice`, `$vpndevice`) but they're **undefined** in the live config.ini! This means the IP address announcement feature is likely broken or using empty strings.

---

## Key Code Changes

### Before (Live System)

**Old pattern in all scripts:**
```bash
#!/usr/bin/env bash
source /opt/app_rpt/config.ini
sourcefile=/opt/app_rpt/config.ini
# ... script logic ...
```

### After (Repository v2.0.1)

**New pattern in all scripts:**
```bash
#!/usr/bin/env bash
source "%%BASEDIR%%/bin/common.sh"
sourcefile="$CONFIG_FILE"
# ... script logic ...
```

**common.sh provides:**
- `set -euo pipefail` - Bash strict mode (exits on errors, undefined vars, pipe failures)
- Config validation (checks required variables exist)
- Logging functions: `log()`, `log_error()`
- Error handling: `die()`, `die_with_error()`
- Validation helpers: `require_var()`, `require_cmd()`, `require_file()`
- Asterisk helpers: `ast_cmd()`, `ast_play()`

---

## Example Changes: sayip.sh

### Live Version Issues

```bash
# No header/license
# No common.sh
case $1 in
lan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show $landevice | awk ...)  # ⚠️ $landevice undefined!
    if [ -z $ip ]; then                       # ⚠️ Unquoted variable
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit                                   # ⚠️ No exit code
    fi
    ;;
wlan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"  # ⚠️ BUG: says "lan" not "wlan"
    ...
*) ;;  # ⚠️ Silent failure on invalid input
```

### Repository Version Improvements

```bash
#!/usr/bin/env bash
# ... GPL license header ...
source "%%BASEDIR%%/bin/common.sh"

case "$1" in  # ✅ Quoted
lan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show "$landevice" | awk ...)  # ✅ Quoted, defined in config
    if [[ -z "$ip" ]]; then                     # ✅ [[ ]] and quoted
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit 0                                   # ✅ Explicit exit code
    fi
    ;;
wlan)
    asterisk -rx "rpt localplay $MYNODE rpt/wlan_ip_address"  # ✅ FIXED: says "wlan"
    ...
*)
    die_with_error "Invalid argument: $1"      # ✅ Error handling with sound
    ;;
esac
```

---

## Upgrade Path Risks

### ❌ What WILL Break if Scripts are Updated Directly

1. **All scripts will fail immediately** - They'll try to source `common.sh` which doesn't exist
2. **Undefined variable errors** - `set -euo pipefail` will cause scripts to exit if config variables are missing
3. **Cron jobs will fail** - All 7 cron jobs run scripts that need common.sh
4. **System functionality loss** - ID rotation, tail messages, time announcements, weather alerts all stop

### ❌ What MIGHT Break Without Careful Migration

1. **Custom config.ini modifications** - User's custom values could be overwritten
2. **Network interface names** - Default `eth0`/`wlan0`/`tun0` might not match user's system
3. **Permission issues** - New scripts might have different permission requirements
4. **Asterisk integration** - Changed Asterisk commands or file paths

---

## Required Upgrade Strategy

### Phase 1: Pre-Upgrade Backup
1. ✅ Backup entire `/opt/app_rpt/` directory
2. ✅ Backup `/etc/asterisk/rpt.conf`
3. ✅ Backup crontab for asterisk user
4. ✅ Create rollback point with timestamp

### Phase 2: Configuration Migration
1. ✅ Parse existing config.ini to extract user values
2. ✅ Detect actual network interface names (`ip link show`)
3. ✅ Merge user values into new config.ini template
4. ✅ Add missing variables (landevice, wlandevice, vpndevice)
5. ✅ Validate merged config (all required variables present)

### Phase 3: Script Installation (ATOMIC)
1. ✅ **Install common.sh FIRST** (before updating any other scripts)
2. ✅ Test common.sh can be sourced successfully
3. ✅ Update all 21 scripts simultaneously (minimize window of breakage)
4. ✅ Set correct permissions (executable, owner asterisk:asterisk)
5. ✅ Verify %%BASEDIR%% placeholder replacement

### Phase 4: Post-Upgrade Validation
1. ✅ Test each script can execute without errors
2. ✅ Verify Asterisk can reload configuration
3. ✅ Check cron jobs are still scheduled
4. ✅ Test a few critical scripts (statekeeper.sh, idkeeper.sh)
5. ✅ Monitor logs for errors

### Phase 5: Rollback on Failure
1. ✅ If any validation fails, restore from backup
2. ✅ Log detailed error messages
3. ✅ Provide user with failure report

---

## Repair Script Requirements

### File Integrity Checks
- ✅ Verify all 22 scripts exist in `/opt/app_rpt/bin/`
- ✅ Verify common.sh exists and can be sourced
- ✅ Check file permissions (755 for scripts, asterisk:asterisk ownership)
- ✅ Verify %%BASEDIR%% placeholders were replaced correctly

### Configuration Validation
- ✅ Verify config.ini exists and is readable
- ✅ Check all required variables are defined
- ✅ Validate network interface variables point to real interfaces
- ✅ Check for trailing/malformed edit timestamps

### Directory Structure
- ✅ Verify `/opt/app_rpt/` directory structure (bin, lib, sounds, backups)
- ✅ Check sound directory symlinks
- ✅ Verify permissions on all directories

### Asterisk Integration
- ✅ Test Asterisk is running and responding
- ✅ Verify rpt.conf syntax is valid
- ✅ Check custom extensions are loaded
- ✅ Test Asterisk CLI commands work

### Cron Jobs
- ✅ Verify 7 cron jobs are scheduled for asterisk user
- ✅ Check cron jobs point to correct script paths
- ✅ Validate scripts referenced in cron are executable

### Sudoers Configuration
- ✅ Check `/etc/sudoers.d/app_rpt_ultra` exists (if required)
- ✅ Verify asterisk user has required sudo privileges
- ✅ Validate user group memberships (sudo, dialout, audio, plugdev)

### Sound Files
- ✅ Verify sound directories exist and contain files
- ✅ Check for required system sounds (rpt/*, tails/*, ids/*)
- ✅ Validate symlinks to Asterisk sound directories

### Log File
- ✅ Verify `/var/log/app_rpt.log` exists and is writable
- ✅ Check for recent errors in log
- ✅ Validate log rotation is configured

---

## Recommendations

### For upgrade.sh:
1. **Interactive mode** - Ask user to confirm before making changes
2. **Dry-run option** - Show what would change without actually changing it
3. **Network interface detection** - Automatically detect and suggest interface names
4. **Preserve custom sounds** - Don't overwrite custom courtesy tones, IDs, or messages
5. **Version checking** - Only upgrade if repo version is newer
6. **Changelog display** - Show user what's new in this version
7. **Safety checks** - Verify Asterisk is stopped or can be gracefully restarted

### For repair.sh:
1. **Non-destructive by default** - Report problems, ask before fixing
2. **Verbose output** - Show what's being checked and what's wrong
3. **Selective repair** - Allow user to choose what to repair
4. **Backup before repair** - Create backup before making any changes
5. **Test mode** - Check without fixing, just report status
6. **Auto-fix option** - `-y` flag to automatically fix all issues

---

## Version Tracking

### Current State:
- ✅ Git commit shows "v2.0.1" in message
- ❌ No VERSION file in repository
- ❌ No version variable in config.ini
- ❌ No way for scripts to detect their version

### Recommendation:
Create `/opt/app_rpt/VERSION` file with:
```
2.0.1
```

And add to config.ini:
```bash
# System version (set by installer/upgrade script)
VERSION=2.0.1
INSTALL_DATE=2026-01-06
LAST_UPGRADE=2026-01-06
```

This allows upgrade.sh to:
- Detect current version
- Compare against repo version
- Skip unnecessary upgrades
- Track upgrade history

---

## Summary

**Upgrade complexity:** HIGH
**Risk of breakage:** HIGH (all scripts modified)
**Rollback capability:** REQUIRED
**Testing recommended:** YES (on non-production system first)

**Primary concerns:**
1. All scripts depend on new common.sh - must be installed first
2. Config variables missing on live system - must be added during upgrade
3. Bash strict mode may expose hidden bugs - thorough testing needed
4. No version tracking - difficult to know what version is installed

**Benefits of upgrade:**
1. Better error handling and logging
2. Consistent code patterns across all scripts
3. Bug fixes (e.g., sayip.sh wlan announcement)
4. Proper variable quoting and validation
5. GPL license headers added to all files
6. Foundation for future maintenance

**Recommendation:** Create both `upgrade.sh` and `repair.sh` scripts to safely manage this transition.
