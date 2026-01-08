# System Maintenance
## Upgrading Your Installation
### upgrade.sh
The upgrade script provides a safe, automated way to upgrade an existing `app_rpt__ultra` installation to the latest version. It preserves your configuration while updating scripts and fixing known issues.

**Key Features:**
- Creates automatic backup before any changes
- Migrates configuration while preserving your settings (node number, API keys, etc.)
- Auto-detects network interfaces for IP address announcements
- Validates installation before committing changes
- Automatic rollback on failure
- Dry-run mode to preview changes

**Usage:**
```bash
cd /usr/src/app_rpt__ultra
git pull
sudo ./upgrade.sh                    # Interactive upgrade with prompts
sudo ./upgrade.sh --dry-run          # Preview changes without applying
sudo ./upgrade.sh --force            # Force upgrade/reinstall same version
sudo ./upgrade.sh --auto-yes         # Automatic upgrade (no prompts)
```

**What It Does:**
1. Checks current version vs. repository version
2. Creates timestamped backup in `/opt/app_rpt/backups/`
3. Migrates your `config.ini` (preserves MYNODE, API keys, settings)
4. Installs new `common.sh` shared library (v2.0+)
5. Updates all 22 scripts with improvements
6. Validates the installation
7. Updates version file to track installed version

**Important Notes:**
> [!CAUTION]
> - The upgrade backs up your crontab, config.ini, and rpt.conf automatically
> - Network interface variables (landevice, wlandevice, vpndevice) are auto-detected if missing
> - Use `--dry-run` first to see what will change
> - Backups are saved with timestamps for easy rollback if needed

**Options:**
- `--dry-run` - Show what would change without making changes
- `--force` - Skip version check, force upgrade even if same version
- `--no-backup` - Skip backup creation (NOT RECOMMENDED)
- `--auto-yes` - Assume yes to all prompts (for automation)
- `--help` - Show detailed help message

**Exit Codes:**
- 0 - Upgrade successful
- 1 - Pre-flight checks failed or user cancelled
- 2 - Backup failed
- 3 - Config migration failed
- 4 - Script installation failed
- 5 - Validation failed (rollback triggered)

### Upgrading Hub-Spoke Architectures
For distributed systems with a hub and multiple child nodes:

**Hub Node (FETCHLOCAL=0):**
1. Run `upgrade.sh` on the hub as normal
2. Child nodes will automatically detect and upgrade (if AUTOUPGRADE=1)

**Child Nodes (FETCHLOCAL=1):**
- **Automatic Upgrade:** Set `AUTOUPGRADE=1` in `config.ini`
  - `configkeeper.sh` (runs every 5 minutes via cron) checks hub version
  - Automatically runs `upgrade.sh --force --auto-yes` when hub version differs
  - All output logged to `/var/log/app_rpt.log`
- **Manual Upgrade:** Keep `AUTOUPGRADE=0` (default)
  - SSH to each child node and run `upgrade.sh` manually

> [!TIP]
> Enable AUTOUPGRADE on child nodes to automatically propagate upgrades from the hub. This eliminates the need to manually upgrade each child node after upgrading the hub.

## System Health & Repair
### repair.sh
The repair script performs comprehensive health checks on your installation and can automatically fix common issues. It's useful for troubleshooting problems or validating your system configuration.

**Key Features:**
- Performs ~100-130 automated health checks across 9 categories
- Interactive repair mode (asks before fixing)
- Check-only mode for diagnostics
- Auto-fix mode for unattended repairs
- Detailed reporting with verbose mode
- Safe repairs with backup creation

**Usage:**
```bash
cd /usr/src/app_rpt__ultra
sudo ./repair.sh                           # Interactive repair with prompts
sudo ./repair.sh --check-only              # Health check only, no repairs
sudo ./repair.sh --auto-fix                # Fix everything automatically
sudo ./repair.sh --verbose                 # Show detailed output
sudo ./repair.sh --report /tmp/health.txt  # Save report to file
```

**Check Categories:**
1. **System Prerequisites** - Root access, `asterisk` user, required commands (`jq`, `rsync`, etc.)
2. **Directory Structure** - Expected directories exist, symlinks correct
3. **Script Files** - All 22 scripts present, executable, correct ownership
4. **Configuration** - `config.ini` validity, required variables set
5. ***Asterisk* Config** - `rpt.conf` exists, *Asterisk* running, `app_rpt` loaded
6. **Cron Jobs** - Expected 7 cron jobs configured for `asterisk` user
7. **Sound Files** - Voice files present, vocabulary files exist
8. **Log File** - `/var/log/app_rpt.log` exists and writable
9. **Runtime Tests** - Scripts can execute, `common.sh` sources correctly

**What It Checks:**
- File permissions and ownership
- Missing or corrupted files
- Configuration variable validity
- Network interface settings (v2.0+)
- *Asterisk* integration
- Crontab entries
- Sound file integrity
- Critical dependencies

**Common Issues It Fixes:**
- Incorrect file permissions (chmod/chown)
- Missing directories
- Broken symlinks
- Missing log file
- User group memberships
- Non-executable scripts

**Options:**
- `--check-only` - Only check for problems, don't fix anything
- `--auto-fix` - Automatically fix all issues without prompting
- `--verbose` - Show detailed output for all checks
- `--report FILE` - Save detailed report to FILE
- `--help` - Show detailed help message

**Exit Codes:**
- 0 - All checks passed (system healthy)
- 1 - Minor issues detected (warnings only)
- 2 - Significant issues detected (failures)
- 3 - Critical error (cannot proceed)

**Example Output:**
```
[PASS] Running as root
[PASS] Installation directory exists: /opt/app_rpt
[PASS] asterisk user exists
[PASS] asterisk user in dialout group
[PASS] asterisk user in audio group
[PASS] Command jq found
[PASS] Script exists and executable: common.sh
[PASS] config.ini exists
[PASS] Config variable set: MYNODE
[PASS] Network variable set: landevice=eth0
[PASS] rpt.conf exists
[PASS] Asterisk is running and responding
[PASS] Cron job exists: idkeeper.sh
[PASS] Vocabulary file exists: 877 words
[PASS] common.sh can be sourced successfully

Total Checks: 98
  Passed:   95
  Failed:   0
  Warnings: 3

✓ System appears healthy!
```

## Uninstalling
### uninstall.sh
To completely remove `app_rpt__ultra` from your system:

```bash
cd /usr/src/app_rpt__ultra
sudo ./uninstall.sh
```

The uninstaller will:
- Remove all installed files from `/opt/app_rpt/`
- Remove crontab entries for `asterisk` user
- Remove sound file symlinks
- Remove sudoers configuration
- Optionally remove `asterisk` user group memberships
- Clean up *Asterisk* configuration modifications

> [!WARNING]
> This will permanently delete your installation. Make sure to backup any custom sounds or configurations you want to keep!


> [!CAUTION]
> The installer configures the `asterisk` account with access to `dialout`, `audio`, and `plugdev` groups. These are required for USB audio and control interfaces in ASL3.

