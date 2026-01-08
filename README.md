# Introduction
_**app_rpt__ultra**_ was designed to be the ultimate controller experience for [Asterisk](https://www.asterisk.org/) [AllStarLink app_rpt](https://www.allstarlink.org/)!  Built on the history and capabilities of standalone repeater controllers from the 1980s-2000s, this platform was designed to combine the art and technology of today with yesteryear.  Some of the features included were takeaways and inspirations from controllers similar to Advanced Computer Controls, Link Communications, Computer Automation Technology and FF Systems.
## How does it work?
All of the frameworks were written in Bash (Bourne again shell) using scripts that are called by _app_rpt_.  The intent was to modify as little as possible so frameworks were relatively immutable and could survive any code updates to Asterisk and _app_rpt_.  Most scripts are called either from within Asterisk (through invocation in rpt.conf) or from local cron jobs.
## Key Features
- Management of repeater states or personalities;
- Rotating identifier and tail messages;
- An advanced message editor with the ability to program messages, courtesy tones and telemetry via DTMF;
- A vocabulary of 877 words and sound effects with dozens of pre-defined phrases[^1];
- Weather alerting system, powered by NOAA NWS alerts;
- Reporting weather conditions, powered by Weather Underground[^2];
- Space weather monitoring with NOAA SWPC integration (geomagnetic storms, radio blackouts, solar radiation);
- Intelligent kerchunk detection with passive monitoring (statistics) and active deterrence (polite reminders);
- Comprehensive statistics logging for transmission pattern analysis;
- Full integration with Asterisk AllStarLink app_rpt without any code modification!
# Installation
## System Requirements
> [!WARNING]
> Only [AllStarLink 3](https://allstarlink.github.io/) is supported; functionality for previous versions of _app_rpt_ and interoperability with HamVoIP have been removed.

> [!NOTE]
> Debian 12 (bookworm) and Debian 13 (trixie) have been tested, along with Asterisk 20 and 22.

## Quick Install
The installer script handles all setup automatically, including:
- Installing dependencies (jq)
- Creating directories and copying files
- Configuring the asterisk user account
- Setting up sound file symlinks
- Generating a temporary voice ID from your callsign
- Installing the crontab for automated operations
- Configuring your node number, callsign, and optional weather services

### Download and Install
```bash
mkdir -p /usr/src
cd /usr/src
git clone https://github.com/AI3I/app_rpt__ultra.git
cd app_rpt__ultra
sudo ./install.sh
```

The installer will prompt you for:
1. **Node Number** (required) - Your AllStarLink node number
2. **Callsign** (required) - Your amateur radio callsign
3. **NWS Zone** (optional) - For weather alerting via NOAA NWS
4. **Weather Underground API Key** (optional) - For weather condition reporting
5. **Weather Underground Station ID** (optional) - Local weather station

### Non-Interactive Install
For automated deployments, use the `-y` flag with environment variables:
```bash
export NODE_NUMBER=1999
export CALLSIGN=MYC4LL
export NWS_ZONE=PAC001
export WU_API_KEY=your_api_key
export WU_STATION=KPAPITTS123
sudo -E ./install.sh -y
```

### Post-Installation
After installation completes:
1. Review `/etc/asterisk/rpt.conf` and verify **duplex** and **rxchannel** settings match your configuration (usbradio.conf or simpleusb.conf)
2. The **idrecording=voice_id** parameter should remain unchanged; it is managed by _idkeeper.sh_
3. Restart Asterisk: `sudo systemctl restart asterisk`

# System Architecture

## Understanding the Installation

While `install.sh` makes setup easy, understanding what happens under the hood helps with troubleshooting and customization. Here's the technical breakdown:

### Directory Structure

**What install.sh creates:**
```
/opt/app_rpt/              # Main installation directory
├── bin/                   # Executable scripts (24 scripts)
├── lib/                   # Data tables and lookup files
│   ├── messagetable.txt   # Slot-to-file mappings (100 slots)
│   ├── vocabulary.txt     # 877-word TMS5220 dictionary
│   ├── characters.txt     # CW character mappings
│   └── *.out              # Runtime data (weather, alerts)
├── sounds/                # Audio files (symlinked to /var/lib/asterisk/sounds)
│   ├── _male/             # TMS5220 male voice (877 words)
│   ├── _female/           # TMS5220 female voice (877 words)
│   ├── _sndfx/            # Sound effects library
│   ├── ids/               # Voice IDs (initial, pending, anxious, special)
│   ├── tails/             # Tail messages (9 slots + weather alerts)
│   ├── wx/                # Weather telemetry (temp, wind, etc.)
│   ├── weather/           # Space weather alerts (G/S/R scales)
│   └── custom/            # User recordings and courtesy tones
├── backups/               # Automatic backups from upgrade.sh
└── config.ini             # Master configuration (NOT in git)

/etc/asterisk/rpt.conf     # Asterisk app_rpt config (NOT in git)
/usr/src/app_rpt__ultra/   # Git repository (source code)
```

**Why this structure?**
- `/opt/app_rpt/`: FHS-compliant location for add-on application packages
- Symlinks to `/var/lib/asterisk/sounds/`: Asterisk can find audio files without path changes
- Separation of code (`/usr/src`) from runtime (`/opt/app_rpt`): Clean upgrades via git pull

### User Account Configuration

**What install.sh does for the asterisk user:**
```bash
# 1. Adds asterisk to dialout group (serial port access for radio interfaces)
usermod -aG dialout asterisk

# 2. Enables shell access (needed for cron jobs to run bash scripts)
chsh -s /bin/bash asterisk

# 3. Sets up home directory
mkdir -p /home/asterisk
chown asterisk:asterisk /home/asterisk

# 4. Configures SSH for remote management (optional)
# Allows scripts to SSH to child nodes for distributed architectures
```

**Why this matters:**
- `dialout` group: Required for USB/serial radio interfaces (SimpleUSB, USBRadio)
- `/bin/bash` shell: Cron jobs run scripts with full bash features (arrays, functions, etc.)
- Home directory: Cron needs a place to write temporary files and logs

### Cron Job Integration

**What install.sh installs:**
```bash
# Asterisk user crontab (crontab -u asterisk -l)
0 0 * * *      /opt/app_rpt/bin/datekeeper.sh      # Daily: Generate date announcements
0 0 * * *      /opt/app_rpt/bin/datadumper.sh      # Daily: Purge old recordings
*/15 * * * *   /opt/app_rpt/bin/weatherkeeper.sh   # Every 15min: Weather & space weather
* * * * *      /opt/app_rpt/bin/timekeeper.sh      # Every minute: Current time
* * * * *      /opt/app_rpt/bin/idkeeper.sh        # Every minute: Manage ID rotation
* * * * *      /opt/app_rpt/bin/tailkeeper.sh      # Every minute: Manage tail messages
* * * * *      /opt/app_rpt/bin/weatheralert.sh    # Every minute: NOAA alert monitoring
```

**How cron scripts work:**
1. Each script sources `/opt/app_rpt/bin/common.sh` for shared functions
2. Reads configuration from `/opt/app_rpt/config.ini`
3. Checks current system state via `asterisk -rx "rpt stats"`
4. Generates audio files in `/opt/app_rpt/sounds/`
5. Updates `/etc/asterisk/rpt.conf` parameters via sed
6. Logs activity to `/var/log/app_rpt.log`

**Example: How idkeeper.sh works every minute:**
```bash
# 1. Source config
source /opt/app_rpt/config.ini  # Gets ROTATEIIDS, INITIALID, etc.

# 2. Check if rotation enabled
if [[ $ROTATEIIDS == 1 ]]; then
    # 3. Get next ID number (1, 2, or 3)
    NEXT_ID=$((CURRENT_ID % 3 + 1))

    # 4. Update rpt.conf parameter
    sed -i "s/^idrecording=.*/idrecording=ids\/initial_id_${NEXT_ID}/" /etc/asterisk/rpt.conf

    # 5. Reload Asterisk config
    asterisk -rx "rpt reload"
fi
```

### Systemd Service (kerchunkd)

**Unlike cron-based scripts, kerchunkd.sh runs as a continuous daemon:**

```ini
# /etc/systemd/system/kerchunkd.service
[Unit]
Description=app_rpt__ultra Kerchunk Detection Daemon
After=asterisk.service
Requires=asterisk.service

[Service]
Type=simple
User=asterisk
Group=asterisk
ExecStart=/opt/app_rpt/bin/kerchunkd.sh
Restart=on-failure
StandardOutput=append:/var/log/app_rpt.log
StandardError=append:/var/log/app_rpt.log

[Install]
WantedBy=multi-user.target
```

**How it integrates:**
1. Polls `asterisk -rx "rpt stats"` every 1 second (vs. cron's 1 minute)
2. Tracks transmission durations in real-time
3. Logs to `/var/log/kerchunk_stats.log` (CSV format)
4. Plays audio warnings via `asterisk -rx "rpt localplay"` (active mode)
5. Survives Asterisk restarts (systemd auto-restarts it)

### Asterisk Integration

**How scripts communicate with Asterisk:**

```bash
# Query repeater statistics
asterisk -rx "rpt stats 1999"
# Returns: keyup count, TX time, system state, temperature, etc.

# Play audio file immediately (localplay)
asterisk -rx "rpt localplay 1999 /opt/app_rpt/sounds/wx/temp"
# Plays without waiting for tail/ID

# Schedule audio in message queue (playback)
asterisk -rx "rpt playback 1999 /opt/app_rpt/sounds/tails/tail_message_5"
# Waits for polite moment (after ID, during hang time)

# Reload configuration
asterisk -rx "rpt reload"
# Re-reads rpt.conf without restarting Asterisk
```

**Message Slot System:**
- **messagetable.txt** maps slot numbers (00-99) to file paths
- Scripts like `msgreader.sh` and `msgwriter.sh` read this table
- DTMF macros reference slots: `*8300#` plays slot 00 (CW ID)
- Allows dynamic content: scripts regenerate files, slots stay the same

**Example flow for playing temperature:**
1. weatherkeeper.sh fetches data from Weather Underground API
2. Builds audio: `"currently 72 degrees"` from TMS5220 vocabulary
3. Writes to: `/opt/app_rpt/sounds/wx/temp.ulaw`
4. messagetable.txt maps slot 70 → `wx/temp`
5. tailkeeper.sh enables slot 70 in rotation
6. Asterisk plays during tail message after transmission

### Sound File Management

**Symlink strategy:**
```bash
# install.sh creates symlinks in Asterisk's sound directory
ln -sf /opt/app_rpt/sounds /var/lib/asterisk/sounds/app_rpt_ultra

# Why?
# - Asterisk searches /var/lib/asterisk/sounds/ by default
# - Scripts write to /opt/app_rpt/sounds/ (clean separation)
# - Symlink makes both paths work
# - No need to modify Asterisk configuration
```

**TMS5220 vocabulary system:**
- 877 individual word files in `_male/` and `_female/`
- Scripts concatenate words to form phrases:
  ```bash
  # Build "currently 72 degrees"
  cat _male/currently.ulaw \
      _male/7.ulaw _male/2.ulaw \
      _male/degrees.ulaw > wx/temp.ulaw
  ```
- Result: Natural-sounding speech without external TTS engines

### Configuration Management

**config.ini variables cascade through the system:**

```ini
# config.ini
MYNODE=1999                    # Your node number
KERCHUNK_ENABLE=1              # Enable kerchunk detection
KERCHUNK_MODE=passive          # Log only (no audio warnings)
SEVEREWEATHER=3                # Weather alert state (0-3)
ROTATEIIDS=1                   # Rotate initial IDs
```

**How scripts use config.ini:**
```bash
#!/bin/bash
# Every script starts with:
source /opt/app_rpt/config.ini

# Then uses variables:
if [[ $KERCHUNK_ENABLE == 1 ]]; then
    # Run kerchunk detection logic
fi

if [[ $SEVEREWEATHER == 1 ]]; then
    # Switch to severe weather mode
    /opt/app_rpt/bin/statekeeper.sh severeweather
fi
```

**Why not /etc/?**
- `/etc/asterisk/rpt.conf`: Asterisk native configuration (complex, AST-specific)
- `/opt/app_rpt/config.ini`: Simple key=value format for bash scripts
- Separation of concerns: Asterisk config vs. script behavior

### What Happens During Upgrade

**upgrade.sh technical steps:**

1. **Version Check:**
   ```bash
   CURRENT_VER=$(grep "^###VERSION=" /opt/app_rpt/bin/common.sh | cut -d= -f2)
   NEW_VER=$(grep "^###VERSION=" app_rpt/bin/common.sh | cut -d= -f2)
   ```

2. **Backup:**
   ```bash
   BACKUP="/opt/app_rpt/backups/upgrade_backup_$(date +%Y%m%d_%H%M%S)"
   cp -a /opt/app_rpt/bin "$BACKUP/bin"
   cp /opt/app_rpt/config.ini "$BACKUP/config.ini"
   cp /etc/asterisk/rpt.conf "$BACKUP/rpt.conf.bkp"
   ```

3. **Config Migration:**
   ```bash
   # Extract current values
   OLD_NODE=$(grep "^MYNODE=" /opt/app_rpt/config.ini | cut -d= -f2)
   OLD_APIKEY=$(grep "^WUAPIKEY=" /opt/app_rpt/config.ini | cut -d= -f2)

   # Install new config template
   cp app_rpt/config.ini.example /opt/app_rpt/config.ini

   # Restore user values
   sed -i "s/^MYNODE=.*/MYNODE=$OLD_NODE/" /opt/app_rpt/config.ini
   sed -i "s/^WUAPIKEY=.*/WUAPIKEY=$OLD_APIKEY/" /opt/app_rpt/config.ini
   ```

4. **Script Installation:**
   ```bash
   # Copy all 24 scripts with version updates
   cp -a app_rpt/bin/*.sh /opt/app_rpt/bin/
   chmod 755 /opt/app_rpt/bin/*.sh
   chown -R asterisk:asterisk /opt/app_rpt/
   ```

5. **Validation:**
   ```bash
   # Check critical files exist
   test -f /opt/app_rpt/bin/common.sh || exit 1
   test -f /opt/app_rpt/config.ini || exit 1

   # Verify version updated
   grep "^###VERSION=$NEW_VER" /opt/app_rpt/bin/common.sh || exit 1
   ```

**Rollback on failure:**
```bash
if [[ $? -ne 0 ]]; then
    echo "Upgrade failed! Rolling back..."
    cp -a "$BACKUP/bin/"* /opt/app_rpt/bin/
    cp "$BACKUP/config.ini" /opt/app_rpt/config.ini
    exit 1
fi
```

### Distributed Architecture (Hub/Child)

**For multi-node deployments:**

```bash
# Hub node (FETCHLOCAL=0)
# - Runs weatherkeeper.sh to fetch weather data
# - Stores in /opt/app_rpt/lib/wunderground.out
# - Child nodes pull this file via rsync/scp

# Child node (FETCHLOCAL=1, FETCHPOINT=hub.example.com)
# - configkeeper.sh runs every 5 minutes
# - Pulls config.ini, scripts, sounds from hub
# - Optionally auto-upgrades when hub version changes (AUTOUPGRADE=1)
```

**How configkeeper.sh works:**
```bash
# 1. Check if child node
if [[ $FETCHLOCAL == 1 ]]; then
    # 2. Sync files from hub
    rsync -avz $FETCHPOINT:/opt/app_rpt/lib/ /opt/app_rpt/lib/
    rsync -avz $FETCHPOINT:/opt/app_rpt/sounds/wx/ /opt/app_rpt/sounds/wx/

    # 3. Check hub version
    HUB_VER=$(ssh $FETCHPOINT "grep VERSION /opt/app_rpt/bin/common.sh")
    LOCAL_VER=$(grep VERSION /opt/app_rpt/bin/common.sh)

    # 4. Auto-upgrade if enabled and versions differ
    if [[ $AUTOUPGRADE == 1 ]] && [[ "$HUB_VER" != "$LOCAL_VER" ]]; then
        cd /usr/src/app_rpt__ultra && git pull && ./upgrade.sh --auto-yes
    fi
fi
```

**Benefits:**
- Weather API: Hub makes one request, all children use cached data
- Consistency: All nodes run same version, same audio files
- Centralized management: Update hub, children auto-update

## Key Takeaways

Understanding this architecture helps you:
- **Troubleshoot**: Know which script handles what function
- **Customize**: Edit scripts knowing how they interact
- **Extend**: Add new scripts following the same patterns
- **Debug**: Check logs, cron output, systemd status
- **Optimize**: Tune timing, disable unused features

The magic is in the integration—bash scripts, Asterisk CLI, systemd services, and cron jobs working together to create a sophisticated repeater controller from simple, readable components.

# System Maintenance
## Upgrading Your Installation
### upgrade.sh
The upgrade script provides a safe, automated way to upgrade an existing _**app_rpt__ultra**_ installation to the latest version. It preserves your configuration while updating scripts and fixing known issues.

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
- **Automatic Upgrade:** Set `AUTOUPGRADE=1` in config.ini
  - configkeeper.sh (runs every 5 minutes via cron) checks hub version
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
1. **System Prerequisites** - Root access, asterisk user, required commands (jq, rsync, etc.)
2. **Directory Structure** - Expected directories exist, symlinks correct
3. **Script Files** - All 22 scripts present, executable, correct ownership
4. **Configuration** - config.ini validity, required variables set
5. **Asterisk Config** - rpt.conf exists, Asterisk running, app_rpt loaded
6. **Cron Jobs** - Expected 7 cron jobs configured for asterisk user
7. **Sound Files** - Voice files present, vocabulary files exist
8. **Log File** - `/var/log/app_rpt.log` exists and writable
9. **Runtime Tests** - Scripts can execute, common.sh sources correctly

**What It Checks:**
- File permissions and ownership
- Missing or corrupted files
- Configuration variable validity
- Network interface settings (v2.0+)
- Asterisk integration
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
[PASS] Command 'jq' found
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
To completely remove _**app_rpt__ultra**_ from your system:

```bash
cd /usr/src/app_rpt__ultra
sudo ./uninstall.sh
```

The uninstaller will:
- Remove all installed files from `/opt/app_rpt/`
- Remove crontab entries for asterisk user
- Remove sound file symlinks
- Remove sudoers configuration
- Optionally remove asterisk user group memberships
- Clean up Asterisk configuration modifications

> [!WARNING]
> This will permanently delete your installation. Make sure to backup any custom sounds or configurations you want to keep!


> [!CAUTION]
> The installer configures the _asterisk_ account with access to _dialout_, _audio_, and _plugdev_ groups. These are required for USB audio and control interfaces in ASL3.
# Operation
Now that you've set up the basics and have legal IDs, it's time to dive deeper into the general operation and behavior of _**app_rpt__ultra**_.  You have configured cron jobs that are now managing general operations of your system, and by periodically dispatching scripts to do our bidding.
## Script Operations
> [!NOTE]
> All scripts reference _/opt/app_rpt/config.ini_ for both runtime and master configuration data.  Should you make any edits to scripts within _/opt/app_rpt/bin_, please be cognizant of any changes that may need to be carried over to _config.ini_ accordingly!
### statekeeper.sh
#### BY INVOCATION ONLY
This script basically the magic and the heart of it all.  The purpose of _statekeeper.sh_ is to manage all of your system's personalities, or states, and effectively do so on demand or when conditions are met.\
\
States can be invoked in any number of ways:
- through the command line;
- through the internal scheduler;
- or using DTMF commands.
#### PERSONALITIES
Several states, or personalities, have been pre-programmed to suit your general day-to-day needs:
|State Name|Purpose|Behaviors|
|-|-|-|
|default|Default Mode|This is the default power-up state that generally cleans up any modifications from other states, and puts your system back to a pre-defined running state.<br />This reads values set to default in _config.ini_ and performs a number of _sed_ replacements, and reloads Asterisk.|
|standard|Standard Mode|This is an alternate to the default power-up state and an ideal area for a general static operating state, especially if you don't intend to leverage daytime or nighttime modes with the scheduler.|
|daytime|Daytime Mode|Fit for daytime operations, this is a great place to set all of your behaviors when both system users and control operators are somewhat attentive.|
|nighttime|Nighttime Mode|This scenario is ideal for locking a few things down, adjusting timers, and preparing your system for nighttime operations when the repeater is largely unattended.|
|net|Net Mode|This adds a lot of brevity, changes courtesy tones, relaxes a few timers, and suppresses telemetry and messaging.|
|tactical|Tactical Mode|Similar to net mode, but ideal for tactical operations with adjusted timers and a distinct courtesy tone.|
|weatheralert|Weather Alert|This announces "weather alert" as a tail message, relaxes timers, but maintains normal operations.|
|severeweather|Severe Weather Mode|This changes the courtesy tone, announces "severe weather alert" for a tail message with aggressive timing, suppresses time-out timers, and sends a two-tone page alerting of severe weather.|
|stealth|Stealth Mode|With the exception of required CW ID, this suppresses all telemetry including voice synthesis, courtesy tones, eliminates hang/tail timers, and disables the scheduler.|
|litzalert|Long Tone Zero (LiTZ) Alert|This generates two-tone pages and announcements when the LiTZ command is executed to garner the attention of control operators who may lend assistance.|
|clock|Grandfather Clock|This emulates the CAT-1000 grandfather clock and can be called through the scheduler at the top of every hour.|
### idkeeper.sh
#### CRONTAB: every minute
This script makes calls into Asterisk to determine current repeater and identifier states, and based upon _config.ini_ and pre-defined behaviors in _statekeeper.sh_ will determine what identifiers it plays, and when.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|SPECIALID|0 or 1 (_boolean_)|Override all IDs with the Special ID?|
|ROTATEIIDS|0 or 1 (_boolean_)|Whether Initial IDs are rotated or not?|
|ROTATEPIDS|0 or 1 (_boolean_)|Whether Pending IDs are rotated or not?|
|INITIALID|{ 1 .. 3 } (_fixed range integer_)|Selection of a specific Initial ID.|
|PENDINGID|{ 1 .. 5 } (_fixed range integer_)|Selection of a specific Pending ID.|
### tailkeeper.sh
#### CRONTAB: every minute
This follows _statekeeper.sh_ behavior and adjusts tail messages based upon operational condition and weather conditions.  By default, it will rotate in messages for current time and local temperature, if Weather Underground is configured.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|ENABLETAIL|0 or 1 (_boolean_)|Whether the tail messages are enabled or not?|
|ENABLETIME|0 or 1 (_boolean_)|Whether periodic time announcements are given in tail messages or not?|
|ENABLETEMP|0 or 1 (_boolean_)|Whether periodic temperature readings are given in tail messages or not?[^2]|
|ROTATETMSG|0 or 1 (_boolean_)|Whether to rotate tail messages or not?|
|TAILMSG|{ 1 .. 9 } (_fixed range integer_)|Selection of a specific tail message.|
### weatheralert.sh
#### CRONTAB: every minute
This monitors NOAA National Weather Service alerts, if configured for your NWS zone, and will trigger _statekeeper.sh_ to change to a weather alert or severe weather alert, if enabled.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|NWSZONE|XXX000|The default value is invalid and should be replaced with your local NWS zone.<br />[NWS Public Forecast Zones](https://www.weather.gov/gis/publiczones)|
|NWSFILE|/opt/app_rpt/lib/nwsalerts.out|Explicit file path where weather alerting data is kept for parsing by **jq**.|
|SEVEREWEATHER|{ 0 .. 3 } (_fixed range integer_)|_**0**_: disables the feature<br />_**1**_: indicates a _severe_ weather alert<br />_**2**_: indicates a weather alert<br />_**3**_: deactivated; conditions are normal|
|RTWXALERT|tails/weather_alert|Relative file path of tail message to be played for routine weather alert.|
|SVWXALERT|tails/severe_weather_alert|Relative file path of tail message to be played for severe weather alert.|
### weatherkeeper.sh
#### CRONTAB: every 15 minutes
This comprehensive weather monitoring script provides local weather conditions via Weather Underground[^2] and space weather monitoring via NOAA Space Weather Prediction Center (SWPC). All weather data is automatically synthesized into TMS5220 audio messages and made available through message slots.

**Features:**
- **Local Weather Conditions**: Temperature, humidity, wind, pressure, precipitation, UV index
- **Space Weather Monitoring**: Geomagnetic storms, radio blackouts, solar radiation
- **UV Index Warnings**: Automated alerts for dangerous UV levels (8+)
- **TMS5220 Audio Synthesis**: All conditions converted to voice announcements
- **Message Slot Integration**: Weather data available via slots 60-79

**Configuration Variables:**
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|FETCHLOCAL|0 or 1 (_boolean_)|Whether to pull data from a local system (i.e. hub system that collates your weather data).<br />The default is _**0**_.|
|WUAPIKEY|_empty_|Should be populated with your Weather Underground API key.[^2]|
|WUSTATION|_empty_|ID of a Weather Underground station that provides you with local weather data.[^2]|
|WUOUTPUT|/opt/app_rpt/lib/wunderground.out|Explicit file path where raw JSON data is kept for parsing by **jq**.|

**Local Weather Conditions (Weather Underground):**
The script fetches and synthesizes the following conditions into message slots 70-79:
- **Temperature** (slot 70): Current temperature with heat index or wind chill
- **Wind** (slot 71): Speed and direction
- **Pressure** (slot 72): Barometric pressure
- **Humidity** (slot 73): Relative humidity percentage
- **Wind Chill** (slot 74): Apparent temperature (cold weather)
- **Heat Index** (slot 75): Apparent temperature (hot weather)
- **Dew Point** (slot 76): Dew point temperature
- **Precipitation Rate** (slot 77): Current rainfall rate
- **Precipitation Total** (slot 78): Total rainfall accumulation
- **UV Index** (slot 79): Current UV index with warnings for dangerous levels

**Space Weather Monitoring (NOAA SWPC):**
Fetches real-time data from NOAA Space Weather Prediction Center and generates TMS5220 warnings for slots 62-69:

**Geomagnetic Storms (G Scale)** - Slots 62-64:
- **G1 (Minor)** - slot 62: "light geo storm alert"
  - Minor power grid fluctuations, aurora visible at high latitudes
- **G2 (Moderate)** - slot 63: "moderate geo storm alert"
  - Voltage alarms on power systems, aurora visible at mid-latitudes
- **G3+ (Strong/Severe)** - slot 64: "severe geo storm warning"
  - Widespread power system issues, aurora visible at low latitudes

**Radio Blackouts (R Scale)** - Slots 65-67:
- **R1 (Minor)** - slot 65: "light radio condition alert"
  - Weak degradation of HF radio on sunlit side
- **R2 (Moderate)** - slot 66: "moderate radio condition alert"
  - Limited HF radio blackouts, loss of contact for tens of minutes
- **R3+ (Strong/Severe)** - slot 67: "severe radio condition warning"
  - Wide area HF blackouts, loss of radio contact for about an hour

**Solar Radiation Storms (S Scale)** - Slots 68-69:
- **S1 (Minor)** - slot 68: "low S storm alert"
  - Minor impacts on polar HF propagation
- **S2+ (Moderate/Strong)** - slot 69: "high S storm warning"
  - Effects on HF propagation, radiation hazard to astronauts

**UV Index Warnings (slot 79):**
Automated warnings for dangerous UV exposure levels:
- **UV 8-10 (Very High)**: "high U V warning"
- **UV 11+ (Extreme)**: "severe U V warning"
- **UV < 8**: No warning file generated

**TMS5220 Audio Innovation:**
- Uses creative word concatenation: "G" + "O" = "geo" (for geomagnetic)
- Uses letter "S" for solar radiation to distinguish from regular storms
- Uses "U V" (spelled out) for UV index warnings
- All vocabulary verified to exist in TMS5220 library

**Data Sources:**
- Local Weather: `https://api.weather.com/v2/pws/observations/current`
- Space Weather: `https://services.swpc.noaa.gov/products/noaa-scales.json`

**Logging:**
All weather updates logged to `/var/log/app_rpt.log`:
```
Weather data updated successfully
Space weather data updated: G0, S0, R0
UV index 6 (MODERATE) - no warning needed
Geomagnetic storm G2 (MODERATE) - geo-storm alert generated
```
### configkeeper.sh
#### CRONTAB: every 5 minutes (child nodes only)
This script maintains configuration synchronization between hub and child nodes in a distributed architecture.  It syncs scripts, configs, sounds, and can automatically upgrade child nodes when the hub version changes.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|FETCHLOCAL|0 or 1 (_boolean_)|Whether this node pulls from a hub system.<br />_**0**_: standalone or hub node<br />_**1**_: child node (pulls from FETCHPOINT)|
|FETCHPOINT|_hostname_|The hub system hostname/IP to pull configuration from.<br />Only used when FETCHLOCAL=1.|
|AUTOUPGRADE|0 or 1 (_boolean_)|Whether to automatically upgrade child nodes when hub version changes.<br />_**0**_: manual upgrades only (default)<br />_**1**_: automatic upgrades via configkeeper.sh<br />**NOTE:** Only applies to child nodes (FETCHLOCAL=1).|
### kerchunkd.sh
#### SYSTEMD SERVICE: continuous daemon
This daemon monitors for consecutive short transmissions (kerchunks) with intelligent detection and optional polite reminders. The daemon runs continuously and responds within seconds of detecting kerchunk patterns, providing immediate behavioral feedback when in active mode, or detailed statistics logging in passive mode.

**How It Works:**
1. Monitors `rpt stats` every 1 second for transmission duration changes
2. Uses three-tier detection logic based on min/max duration range:
   - **< MIN_DURATION**: Ignored (noise/blips, not counted)
   - **MIN to MAX_DURATION**: Counted as kerchunk
   - **> MAX_DURATION**: Normal transmission (resets counter)
3. Tracks consecutive kerchunks with smart reset on normal transmissions
4. **Passive mode** (default): Logs statistics to `/var/log/kerchunk_stats.log`
5. **Active mode**: Plays "Please identify" after threshold + logs statistics
6. Rate limits warnings to prevent harassment (default: 30 seconds between warnings)

**Configuration Variables:**
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|KERCHUNK_ENABLE|0 or 1 (_boolean_)|Enable kerchunk monitoring.<br />_**0**_: disabled<br />_**1**_: enabled (default)<br />**Note:** Auto-disabled by statekeeper during net, stealth, and tactical modes|
|KERCHUNK_MODE|passive or active|Detection mode.<br />_**passive**_: log only (default)<br />_**active**_: log + play warning message|
|KERCHUNK_THRESHOLD|_integer_|Number of consecutive kerchunks before triggering (logging or warning).<br />Default: _**3**_|
|KERCHUNK_MIN_DURATION|_decimal_|Minimum transmission duration (seconds) to count as kerchunk.<br />Transmissions shorter than this are ignored (noise/blips).<br />Default: _**0.2**_ seconds|
|KERCHUNK_MAX_DURATION|_decimal_|Maximum transmission duration (seconds) to count as kerchunk.<br />Transmissions longer than this reset the counter (normal transmission).<br />Default: _**1.5**_ seconds|
|KERCHUNK_WAITLIMIT|_integer_|Seconds between warning messages (rate limiting, active mode only).<br />Default: _**30**_ seconds|

**Default Message:**
- Uses TMS5220 vocabulary: "Please identify"
- Files automatically concatenated: `please.ulaw` + `identify.ulaw`
- Creates: `/opt/app_rpt/sounds/custom/kerchunk_reminder.ulaw`

**Custom Message (Optional):**
You can record a custom message and save it as:
```
/opt/app_rpt/sounds/custom/kerchunk_reminder.ulaw
```
The daemon automatically uses the custom file if it exists.

**Service Management:**
```bash
# Check status
sudo systemctl status kerchunkd.service

# Start/stop/restart
sudo systemctl start kerchunkd.service
sudo systemctl stop kerchunkd.service
sudo systemctl restart kerchunkd.service

# Enable/disable auto-start on boot
sudo systemctl enable kerchunkd.service
sudo systemctl disable kerchunkd.service

# View logs
sudo journalctl -u kerchunkd.service -f
tail -f /var/log/app_rpt.log | grep kerchunk
```

**Statistics Logging:**
The daemon logs all transmissions to `/var/log/kerchunk_stats.log` in CSV format:
```
Timestamp, Node, Duration, Consecutive_Count, Warning_Played, Type, State
2026-01-07 20:00:00, 504381, 0.6s, 1, no, kerchunk, state_0
2026-01-07 20:00:10, 504381, 0.7s, 2, no, kerchunk, state_0
2026-01-07 20:00:20, 504381, 0.8s, 3, no-passive, kerchunk, state_0
2026-01-07 20:00:30, 504381, 5.2s, 0, no, normal, state_0
```

This provides valuable data for analyzing transmission patterns and tuning detection parameters.

**Testing Passive Mode (default):**
1. Set `KERCHUNK_ENABLE=1` and `KERCHUNK_MODE=passive` in config.ini
2. Restart daemon: `sudo systemctl restart kerchunkd.service`
3. Make 3 short transmissions (0.5-1.0 seconds each)
4. Check logs: `tail -f /var/log/kerchunk_stats.log`
5. Look for consecutive count reaching threshold
6. No audio warning will play - passive mode logs only

**Testing Active Mode:**
1. Set `KERCHUNK_MODE=active` in config.ini
2. Restart daemon: `sudo systemctl restart kerchunkd.service`
3. Make 3 short transmissions (0.5-1.0 seconds each)
4. Wait 2-3 seconds after last transmission
5. Listen for "Please identify" warning
6. Check logs to verify both audio and statistics

**Tuning Detection:**
- Increase `KERCHUNK_MAX_DURATION` if legitimate short transmissions are flagged
- Decrease `KERCHUNK_MIN_DURATION` if very short kerchunks are missed
- Adjust `KERCHUNK_THRESHOLD` based on desired sensitivity
- Review `/var/log/kerchunk_stats.log` to analyze actual transmission patterns

**Note:** The daemon requires `asterisk.service` to be running and uses app_rpt's internal statistics for transmission timing.
### datadumper.sh
#### CRONTAB: midnight daily
This purges old recordings after they have aged by the defined period in the script.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|RETENTION|_integer_|The number of days to keep recordings.<br />The default is _**60**_ days and recordings are stored in _/opt/asterisk_ with status logs.|
### datekeeper.sh
#### CRONTAB: midnight daily
This generates a new date message at midnight daily for playback by invocation.\
_There are no configurable options._
### timekeeper.sh
#### CRONTAB: every minute
This generates time messages every minute for playback either in tail messages or by invocation.\
_There are no configurable options._
## Message Management
### msgreader.sh
This reads back messages stored in the message table listed below.
#### EXAMPLES
* We want to hear the current temperature outside:
```
msgreader.sh 70
```
* We want to hear Repeaterism #16 because it's cute:
```
msgreader.sh 84
```
* We want to check to make sure our Special ID is as we programmed it:
```
msgreader.sh 10
```
#### BY INVOCATION ONLY
### msgwriter.sh
#### BY INVOCATION ONLY
This script can write messages into slots using the vocabulary and character tables listed below.
> [!NOTE]
> 1. Slot _**00** is special_ and is for the CW ID, which writes to the _**idtalkover**_ parameter in rpt.conf.
> 2. Slots **01** through **50** are customizable through the message writer, while slots **51** through **99** are pre-programmed and cannot be overwritten by this tool.
> 3. Character `D` delimits the slot from the message, and `*` delimits each character or vocabulary word.

#### EXAMPLES
* We want to write CW ID into slot 00 with "MYC4LL":
```
msgwriter.sh 00D61*93*23*04*53*53
```
* We want to write a voice message into slot 04 for the Anxious ID that reads back "_M Y C 4 L L REPEATER_":
```
msgwriter.sh 04D061*093*023*004*053*053*080
```
> [!TIP]
> Add _msgwriter.sh_ into your _rpt.conf_ for full DTMF versatility to write messages over the air!
## Courtesy Tone Management
### ctwriter.sh
#### BY INVOCATION ONLY
This is an invaluable script to write courtesy tones into various positions.  Special care was given to ensure three usable types could be written:  voice messages, tone stanzas, and CW characters.  Please refer to the examples below to understand how these are constructed.
#### TELEMETRY TYPES
|Delineator|Type|Description|
|-|-|-|
|A|vocabulary|Uses a voice vocabulary word or sound effect|
|B|CW characters|Uses a CW character|
|C|tone telemetry|This is the standard sine wave tonal format|
#### USABLE TYPES
|Slot(s)|Type|Description|
|-|-|-|
|00..95|_standard_|Standard courtesy tones|
|96|remotemon|Issued when system is in remote monitoring mode|
|97|remotetx|Issued when system is in remote transmit mode|
|98|cmdmode|Issued when command mode is in operation|
|99|functcomplete|Issued when a function is complete|
#### EXAMPLES
> [!NOTE]
> 1. Slot **00** _is special_; while it can be overwritten, it is intended to be silent.
> 2. Slots **01** through **95** are customizable for general use and playback.
> 3. Slots **96** through **99** have special purposes, as listed above...do be careful!
> 4. Character `D` is a delimter that allows multiple tone stanzas to be strung together, while `*` is a single parameter delimter.

* We want to write the word "BATTERY" to courtesy tone 47:
```
ctwriter.sh 47A142
```
* We want to put CW character "N" (#62 from the CW table) in for our net courtesy tone in slot 54:
```
ctwriter.sh 54B62
```
* We want the "bumblebee" courtesy tone (a sequential 330, 500 and 660 Hz sequence) to reside in slot 36 with 100 millisecond tone lengths and an amplitude of 2048:
```
ctwriter.sh 36C330*0*100*2048*2048D500*0*100*2048D660*0*100*2048
```
* We want the "piano chord" courtesy tone (a chorded 660 and 880 Hz sequence) to reside in slot 12 with a 150 millisecond duration and amplitude of 4096:
```
ctwriter.sh 12C660*880*150*4096
```
> [!TIP]
> Add _ctwriter.sh_ into your _rpt.conf_ for full DTMF versatility to write complex courtesy tones from your radio's keypad!
### ctkeeper.sh
#### BY INVOCATION ONLY
This script lends the ability to select from 95 different courtesy tones to suit your needs.
#### USABLE TYPES
|Types|Values|Description|
|-|-|-|
|linkunkeyct|{ 00 .. 95 }|Issued when link unkeys|
|remotect|{ 00 .. 95 }|Issued when remote is activated|
|unlinkedct|{ 00 .. 95 }|Issued when system is unlinked altogether|

#### EXAMPLES
* We want to change _linkunkeyct_ to courtesy tone 24:
```
ctkeeper.sh linkunkeyct 24
```
* We want to change _unlinkedct_ to courtesy tone 78:
```
ctkeeper.sh unlinkedct 78
```
> [!TIP]
> Add _ctkeeper.sh_ into your _rpt.conf_ for ability to change courtesy tones remotely!
## Message Tables
### CW Characters
#### RADIO KEYPAD FORMAT
|       |       |       |
| :---: | :---: | :---: |
| <h1>1</h1> <br /> `-  %  /  :` <br /> 10 11 12 14 <br /> | <h1>2</h1> <br /> `A  B  C  ;` <br /> 21 22 23 24 <br /> | <h1>3</h1> <br /> `,  D  E  F  +` <br /> 30 31 32 33 34 <br /> |
| <h1>4</h1> <br /> `'  G  H  I  "` <br /> 40 41 42 43 44 <br /> | <h1>5</h1> <br /> `(  J  K  L  )` <br /> 50 51 52 53 54 <br /> | <h1>6</h1> <br /> `.  M  N  O  @` <br /> 60 61 62 63 64 <br /> |
| <h1>7</h1> <br /> `Q  P  R  S  =` <br /> 70 71 72 73 74 <br /> | <h1>8</h1> <br /> `_  T  U  V  $` <br /> 80 81 82 83 84 <br /> | <h1>9</h1> <br /> `W  X  Y  Z  &` <br /> 91 92 93 90 94 <br /> |
| <h1>*</h1> <br /> _unassigned_ | <h1>0</h1> `0 1 2 3 4` <br /> 00 01 02 03 04 <br /> `5 6 7 8 9` <br /> 05 06 07 08 09 | <h1>#</h1> <br /> _unassigned_ |
#### NUMERICAL ORDER
|Slot|Character
|-|-|
|00|0|
|01|1|
|02|2|
|03|3|
|04|4|
|05|5|
|06|6|
|07|7|
|08|8|
|09|9|
|10|-|
|11|%|
|12|/|
|14|:|
|20|?|
|21|A|
|22|B|
|23|C|
|24|;|
|30|,|
|31|D|
|32|E|
|33|F|
|34|+|
|40|'|
|41|G|
|42|H|
|43|I|
|44|"|
|50|(|
|51|J|
|52|K|
|53|L|
|54|)|
|60|.|
|61|M|
|62|N|
|63|O|
|64|@|
|70|Q|
|71|P|
|72|R|
|73|S|
|74|=|
|80|_|
|81|T|
|82|U|
|83|V|
|84|$|
|90|Z|
|91|W|
|92|X|
|93|Y|
|94|&|
### Word Vocabulary
|Slot|Path|Word|
|-|-|-|
|801|_female/1.ulaw|1|
|802|_female/2.ulaw|2|
|803|_female/3.ulaw|3|
|804|_female/4.ulaw|4|
|805|_female/5.ulaw|5|
|806|_female/6.ulaw|6|
|807|_female/7.ulaw|7|
|808|_female/8.ulaw|8|
|809|_female/9.ulaw|9|
|810|_female/10.ulaw|10|
|811|_female/11.ulaw|11|
|812|_female/12.ulaw|12|
|813|_female/13.ulaw|13|
|814|_female/14.ulaw|14|
|854|_female/15.ulaw|15|
|864|_female/16.ulaw|16|
|874|_female/17.ulaw|17|
|884|_female/18.ulaw|18|
|894|_female/19.ulaw|19|
|820|_female/20.ulaw|20|
|816|_female/21.ulaw|21|
|817|_female/22.ulaw|22|
|818|_female/23.ulaw|23|
|819|_female/24.ulaw|24|
|826|_female/25.ulaw|25|
|827|_female/26.ulaw|26|
|828|_female/27.ulaw|27|
|829|_female/28.ulaw|28|
|835|_female/29.ulaw|29|
|830|_female/30.ulaw|30|
|836|_female/31.ulaw|31|
|837|_female/32.ulaw|32|
|838|_female/33.ulaw|33|
|839|_female/34.ulaw|34|
|846|_female/35.ulaw|35|
|847|_female/36.ulaw|36|
|848|_female/37.ulaw|37|
|849|_female/38.ulaw|38|
|851|_female/39.ulaw|39|
|840|_female/40.ulaw|40|
|852|_female/41.ulaw|41|
|853|_female/42.ulaw|42|
|856|_female/43.ulaw|43|
|857|_female/44.ulaw|44|
|858|_female/45.ulaw|45|
|859|_female/46.ulaw|46|
|890|_female/47.ulaw|47|
|866|_female/48.ulaw|48|
|867|_female/49.ulaw|49|
|850|_female/50.ulaw|50|
|868|_female/51.ulaw|51|
|869|_female/52.ulaw|52|
|896|_female/53.ulaw|53|
|871|_female/54.ulaw|54|
|872|_female/55.ulaw|55|
|897|_female/56.ulaw|56|
|876|_female/57.ulaw|57|
|877|_female/58.ulaw|58|
|878|_female/59.ulaw|59|
|879|_female/00.ulaw|00|
|880|_female/01.ulaw|01|
|898|_female/02.ulaw|02|
|899|_female/03.ulaw|03|
|901|_female/04.ulaw|04|
|902|_female/05.ulaw|05|
|886|_female/06.ulaw|06|
|887|_female/07.ulaw|07|
|888|_female/08.ulaw|08|
|889|_female/09.ulaw|09|
|832|_female/a_m.ulaw|A.M.|
|842|_female/afternoon.ulaw|AFTERNOON|
|843|_female/evening.ulaw|EVENING|
|834|_female/good.ulaw|GOOD|
|862|_female/good_afternoon.ulaw|GOOD AFTERNOON|
|863|_female/good_evening.ulaw|GOOD EVENING|
|861|_female/good_morning.ulaw|GOOD MORNING|
|823|_female/is.ulaw|IS|
|841|_female/morning.ulaw|MORNING|
|824|_female/o_clock.ulaw|O'CLOCK|
|800|_female/oh.ulaw|OH|
|833|_female/p_m.ulaw|P.M.|
|821|_female/the.ulaw|THE|
|844|_female/the_time_is.ulaw|THE TIME IS|
|822|_female/time.ulaw|TIME|
|021|_male/a.ulaw|A|
|111|_male/a_c.ulaw|A.C.|
|110|_male/a_m.ulaw|A.M.|
|992|_male/abort.ulaw|ABORT|
|855|_male/about.ulaw|ABOUT|
|112|_male/above.ulaw|ABOVE|
|114|_male/acknowledge.ulaw|ACKNOWLEDGE|
|115|_male/action.ulaw|ACTION|
|944|_male/adjust.ulaw|ADJUST|
|119|_male/advance.ulaw|ADVANCE|
|916|_male/advanced.ulaw|ADVANCED|
|116|_male/advise.ulaw|ADVISE|
|117|_male/aerial.ulaw|AERIAL|
|118|_male/affirmative.ulaw|AFFIRMATIVE|
|120|_male/air.ulaw|AIR|
|040|_male/alert.ulaw|ALERT|
|685|_male/all.ulaw|ALL|
|134|_male/allstarlink.ulaw|ALLSTARLINK|
|124|_male/aloft.ulaw|ALOFT|
|621|_male/alpha.ulaw|ALPHA|
|125|_male/alternate.ulaw|ALTERNATE|
|127|_male/altitude.ulaw|ALTITUDE|
|121|_male/am.ulaw|A.M.|
|917|_male/amateur.ulaw|AMATEUR|
|122|_male/amp.ulaw|AMP|
|831|_male/amps.ulaw|AMPS|
|074|_male/and.ulaw|AND|
|128|_male/answer.ulaw|ANSWER|
|131|_male/april.ulaw|APRIL|
|713|_male/area.ulaw|AREA|
|130|_male/ares.ulaw|ARES|
|132|_male/arrival.ulaw|ARRIVAL|
|123|_male/arrive.ulaw|ARRIVE|
|133|_male/as.ulaw|AS|
|742|_male/at.ulaw|AT|
|135|_male/august.ulaw|AUGUST|
|918|_male/auto.ulaw|AUTO|
|741|_male/automatic.ulaw|AUTOMATIC|
|129|_male/automation.ulaw|AUTOMATION|
|136|_male/autopilot.ulaw|AUTOPILOT|
|137|_male/auxiliary.ulaw|AUXILIARY|
|022|_male/b.ulaw|B|
|138|_male/band.ulaw|BAND|
|139|_male/bang.ulaw|BANG|
|140|_male/bank.ulaw|BANK|
|141|_male/base.ulaw|BASE|
|142|_male/battery.ulaw|BATTERY|
|143|_male/below.ulaw|BELOW|
|660|_male/between.ulaw|BETWEEN|
|144|_male/blowing.ulaw|BLOWING|
|145|_male/board.ulaw|BOARD|
|146|_male/boost.ulaw|BOOST|
|147|_male/bozo.ulaw|BOZO|
|148|_male/brake.ulaw|BRAKE|
|622|_male/bravo.ulaw|BRAVO|
|743|_male/break.ulaw|BREAK|
|150|_male/broke.ulaw|BROKE|
|151|_male/broken.ulaw|BROKEN|
|993|_male/button.ulaw|BUTTON|
|152|_male/by.ulaw|BY|
|023|_male/c.ulaw|C|
|153|_male/cabin.ulaw|CABIN|
|735|_male/calibrate.ulaw|CALIBRATE|
|751|_male/call.ulaw|CALL|
|155|_male/calling.ulaw|CALLING|
|156|_male/calm.ulaw|CALM|
|664|_male/cancel.ulaw|CANCEL|
|711|_male/caution.ulaw|CAUTION|
|158|_male/ceiling.ulaw|CEILING|
|161|_male/center.ulaw|CENTER|
|875|_male/change.ulaw|CHANGE|
|623|_male/charlie.ulaw|CHARLIE|
|865|_male/check.ulaw|CHECK|
|720|_male/circuit.ulaw|CIRCUIT|
|163|_male/clear.ulaw|CLEAR|
|165|_male/climb.ulaw|CLIMB|
|945|_male/clock.ulaw|CLOCK|
|166|_male/closed.ulaw|CLOSED|
|926|_male/club.ulaw|CLUB|
|075|_male/code.ulaw|CODE|
|167|_male/come.ulaw|COME|
|169|_male/command.ulaw|COMMAND|
|721|_male/complete.ulaw|COMPLETE|
|927|_male/computer.ulaw|COMPUTER|
|168|_male/condition.ulaw|CONDITION|
|170|_male/congratulations.ulaw|CONGRATULATIONS|
|940|_male/connect.ulaw|CONNECT|
|154|_male/connected.ulaw|CONNECTED|
|171|_male/contact.ulaw|CONTACT|
|624|_male/control.ulaw|CONTROL|
|172|_male/converging.ulaw|CONVERGING|
|173|_male/count.ulaw|COUNT|
|157|_male/county.ulaw|COUNTY|
|174|_male/course.ulaw|COURSE|
|950|_male/crane.ulaw|CRANE|
|175|_male/crosswind.ulaw|CROSSWIND|
|149|_male/current.ulaw|CURRENT|
|162|_male/cycle.ulaw|CYCLE|
|031|_male/d.ulaw|D|
|177|_male/d_c.ulaw|D.C.|
|712|_male/danger.ulaw|DANGER|
|178|_male/day.ulaw|DAY|
|952|_male/days.ulaw|DAYS|
|928|_male/dayton.ulaw|DAYTON|
|181|_male/december.ulaw|DECEMBER|
|184|_male/decode.ulaw|DECODE|
|182|_male/decrease.ulaw|DECREASE|
|183|_male/decreasing.ulaw|DECREASING|
|189|_male/degree.ulaw|DEGREE|
|722|_male/degrees.ulaw|DEGREES
|631|_male/delta.ulaw|DELTA|
|185|_male/departure.ulaw|DEPARTURE|
|953|_male/device.ulaw|DEVICE|
|936|_male/dial.ulaw|DIAL|
|186|_male/dinner.ulaw|DINNER|
|752|_male/direction.ulaw|DIRECTION|
|194|_male/disconnected.ulaw|DISCONNECTED|
|954|_male/display.ulaw|DISPLAY|
|955|_male/door.ulaw|DOOR|
|654|_male/down.ulaw|DOWN|
|188|_male/downwind.ulaw|DOWNWIND|
|190|_male/drive.ulaw|DRIVE|
|191|_male/drizzle.ulaw|DRIZZLE|
|192|_male/dust.ulaw|DUST|
|032|_male/e.ulaw|E|
|754|_male/east.ulaw|EAST|
|632|_male/echo.ulaw|ECHO|
|197|_male/echolink.ulaw|ECHOLINK|
|008|_male/eight.ulaw|EIGHT|
|018|_male/eighteen.ulaw|EIGHTEEN|
|242|_male/eighteenth.ulaw|EIGHTEENTH|
|243|_male/eighth.ulaw|EIGHTH|
|943|_male/electrician.ulaw|ELECTRICIAN|
|196|_male/elevation.ulaw|ELEVATION|
|011|_male/eleven.ulaw|ELEVEN|
|219|_male/eleventh.ulaw|ELEVENTH|
|937|_male/emergency.ulaw|EMERGENCY|
|220|_male/encode.ulaw|ENCODE|
|198|_male/engine.ulaw|ENGINE|
|995|_male/enter.ulaw|ENTER|
|893|_male/equal.ulaw|EQUAL|
|211|_male/error.ulaw|ERROR|
|212|_male/estimated.ulaw|ESTIMATED|
|213|_male/evacuate.ulaw|EVACUATE|
|214|_male/evacuation.ulaw|EVACUATION|
|761|_male/exit.ulaw|EXIT|
|215|_male/expect.ulaw|EXPECT|
|033|_male/f.ulaw|F|
|755|_male/fail.ulaw|FAIL|
|216|_male/failure.ulaw|FAILURE|
|930|_male/farad.ulaw|FARAD|
|217|_male/farenheit.ulaw|FARENHEIT|
|925|_male/fast.ulaw|FAST|
|218|_male/february.ulaw|FEBRUARY|
|448|_male/feet.ulaw|FEET|
|015|_male/fifteen.ulaw|FIFTEEN|
|232|_male/fifteenth.ulaw|FIFTEENTH|
|233|_male/fifth.ulaw|FIFTH|
|223|_male/filed.ulaw|FILED|
|224|_male/final.ulaw|FINAL|
|634|_male/fire.ulaw|FIRE|
|225|_male/first.ulaw|FIRST|
|005|_male/five.ulaw|FIVE|
|227|_male/flaps.ulaw|FLAPS|
|228|_male/flight.ulaw|FLIGHT|
|960|_male/flow.ulaw|FLOW|
|230|_male/fog.ulaw|FOG|
|231|_male/for.ulaw|FOR|
|004|_male/four.ulaw|FOUR|
|014|_male/fourteen.ulaw|FOURTEEN|
|279|_male/fourteenth.ulaw|FOURTEENTH|
|234|_male/fourth.ulaw|FOURTH|
|633|_male/foxtrot.ulaw|FOXTROT|
|235|_male/freedom.ulaw|FREEDOM|
|236|_male/freezing.ulaw|FREEZING|
|610|_male/frequency.ulaw|FREQUENCY|
|237|_male/friday.ulaw|FRIDAY|
|064|_male/from.ulaw|FROM|
|238|_male/front.ulaw|FRONT|
|241|_male/full.ulaw|FULL|
|041|_male/g.ulaw|G|
|991|_male/gallons.ulaw|GALLONS|
|845|_male/gate.ulaw|GATE|
|244|_male/gear.ulaw|GEAR|
|962|_male/get.ulaw|GET|
|245|_male/glide.ulaw|GLIDE|
|895|_male/go.ulaw|GO|
|641|_male/golf.ulaw|GOLF|
|762|_male/green.ulaw|GREEN|
|347|_male/grouch.ulaw|GROUCH|
|349|_male/grouchy.ulaw|GROUCHY|
|248|_male/ground.ulaw|GROUND|
|961|_male/gauge.ulaw|GAUGE|
|250|_male/gusting_to.ulaw|GUSTING TO|
|042|_male/h.ulaw|H|
|251|_male/hail.ulaw|HAIL|
|252|_male/half.ulaw|HALF|
|938|_male/ham.ulaw|HAM|
|946|_male/hamfest.ulaw|HAMFEST|
|947|_male/hamvention.ulaw|HAMVENTION|
|253|_male/have.ulaw|HAVE|
|254|_male/hazardous.ulaw|HAZARDOUS|
|255|_male/haze.ulaw|HAZE|
|257|_male/heavy.ulaw|HEAVY|
|258|_male/help.ulaw|HELP|
|260|_male/henry.ulaw|HENRY|
|684|_male/hertz.ulaw|HERTZ|
|763|_male/high.ulaw|HIGH|
|963|_male/hold.ulaw|HOLD|
|615|_male/home.ulaw|HOME|
|642|_male/hotel.ulaw|HOTEL|
|261|_male/hour.ulaw|HOUR|
|655|_male/hours.ulaw|HOURS|
|640|_male/hundred.ulaw|HUNDRED|
|221|_male/hundredth.ulaw|HUNDREDTH|
|222|_male/hundredths.ulaw|HUNDREDTHS|
|043|_male/i.ulaw|I|
|262|_male/ice.ulaw|ICE|
|263|_male/icing.ulaw|ICING|
|264|_male/identify.ulaw|IDENTIFY|
|266|_male/ignite.ulaw|IGNITE|
|267|_male/ignition.ulaw|IGNITION|
|268|_male/immediately.ulaw|IMMEDIATELY|
|270|_male/in.ulaw|IN|
|271|_male/inbound.ulaw|INBOUND|
|964|_male/inch.ulaw|INCH|
|272|_male/increase.ulaw|INCREASE|
|229|_male/increasing.ulaw|INCREASING|
|274|_male/increasing_to.ulaw|INCREASING TO|
|643|_male/india.ulaw|INDIA|
|275|_male/indicated.ulaw|INDICATED|
|276|_male/inflight.ulaw|INFLIGHT|
|996|_male/information.ulaw|INFORMATION|
|277|_male/inner.ulaw|INNER|
|256|_male/inspect.ulaw|INSPECT|
|785|_male/inspector.ulaw|INSPECTOR|
|764|_male/intruder.ulaw|INTRUDER|
|733|_male/is.ulaw|IS|
|281|_male/it.ulaw|IT|
|051|_male/j.ulaw|J|
|282|_male/january.ulaw|JANUARY|
|651|_male/juliet.ulaw|JULIET|
|283|_male/july.ulaw|JULY|
|284|_male/june.ulaw|JUNE|
|259|_male/just.ulaw|JUST|
|052|_male/k.ulaw|K|
|285|_male/key.ulaw|KEY|
|652|_male/kilo.ulaw|KILO|
|265|_male/kit.ulaw|KIT|
|286|_male/knots.ulaw|KNOTS|
|269|_male/knowledge.ulaw|KNOWLEDGE|
|053|_male/l.ulaw|L|
|287|_male/land.ulaw|LAND|
|288|_male/landing.ulaw|LANDING|
|956|_male/late.ulaw|LATE|
|291|_male/launch.ulaw|LAUNCH|
|292|_male/lean.ulaw|LEAN|
|770|_male/left.ulaw|LEFT|
|293|_male/leg.ulaw|LEG|
|273|_male/less.ulaw|LESS|
|294|_male/less_than.ulaw|LESS THAN|
|295|_male/level.ulaw|LEVEL|
|934|_male/light.ulaw|LIGHT|
|653|_male/lima.ulaw|LIMA|
|278|_male/limited.ulaw|LIMITED|
|942|_male/line.ulaw|LINE|
|998|_male/link.ulaw|LINK|
|296|_male/list.ulaw|LIST|
|297|_male/lock.ulaw|LOCK|
|298|_male/long.ulaw|LONG|
|957|_male/look.ulaw|LOOK|
|771|_male/low.ulaw|LOW|
|310|_male/lower.ulaw|LOWER|
|311|_male/lunch.ulaw|LUNCH|
|061|_male/m.ulaw|M|
|084|_male/machine.ulaw|MACHINE|
|312|_male/maintain.ulaw|MAINTAIN|
|965|_male/manual.ulaw|MANUAL|
|313|_male/march.ulaw|MARCH|
|299|_male/mark.ulaw|MARK|
|314|_male/marker.ulaw|MARKER|
|315|_male/may.ulaw|MAY|
|316|_male/mayday.ulaw|MAYDAY|
|920|_male/me.ulaw|ME|
|317|_male/mean.ulaw|MEAN|
|970|_male/measure.ulaw|MEASURE|
|290|_male/meet.ulaw|MEET|
|035|_male/meeting.ulaw|MEETING|
|680|_male/mega.ulaw|MEGA|
|164|_male/message.ulaw|MESSAGE|
|625|_male/messages.ulaw|MESSAGES|
|620|_male/meter.ulaw|METER|
|931|_male/micro.ulaw|MICRO|
|661|_male/mike.ulaw|MIKE|
|176|_male/mile.ulaw|MILE|
|322|_male/miles.ulaw|MILES|
|971|_male/mill.ulaw|MILL|
|825|_male/milli.ulaw|MILLI-|
|323|_male/million.ulaw|MILLION|
|612|_male/minus.ulaw|MINUS|
|179|_male/minute.ulaw|MINUTE|
|645|_male/minutes.ulaw|MINUTES|
|324|_male/mist.ulaw|MIST|
|958|_male/mobile.ulaw|MOBILE|
|180|_male/mode.ulaw|MODE|
|326|_male/moderate.ulaw|MODERATE|
|327|_male/monday.ulaw|MONDAY|
|328|_male/month.ulaw|MONTH|
|187|_male/more.ulaw|MORE|
|330|_male/more_than.ulaw|MORE THAN|
|195|_male/moron.ulaw|MORON|
|972|_male/motor.ulaw|MOTOR|
|973|_male/move.ulaw|MOVE|
|332|_male/much.ulaw|MUCH|
|199|_male/my.ulaw|MY|
|602|_male/n.ulaw|N|
|333|_male/near.ulaw|NEAR|
|334|_male/negative.ulaw|NEGATIVE|
|205|_male/net.ulaw|NET|
|335|_male/new.ulaw|NEW|
|336|_male/next.ulaw|NEXT|
|337|_male/night.ulaw|NIGHT|
|009|_male/nine.ulaw|NINE|
|019|_male/nineteen.ulaw|NINETEEN|
|200|_male/nineteenth.ulaw|NINETEENTH|
|201|_male/ninth.ulaw|NINTH|
|342|_male/no.ulaw|NO|
|202|_male/node.ulaw|NODE|
|772|_male/north.ulaw|NORTH|
|695|_male/not.ulaw|NOT|
|662|_male/november.ulaw|NOVEMBER|
|734|_male/number.ulaw|NUMBER|
|063|_male/o.ulaw|O|
|345|_male/o_clock.ulaw|O' CLOCK|
|203|_male/o_k.ulaw|O.K.|
|204|_male/obscure.ulaw|OBSCURE|
|344|_male/obscured.ulaw|OBSCURED|
|346|_male/october.ulaw|OCTOBER|
|694|_male/of.ulaw|OF|
|614|_male/off.ulaw|OFF|
|348|_male/ohio.ulaw|OHIO|
|206|_male/ohm.ulaw|OHM|
|933|_male/ohms.ulaw|OHMS|
|350|_male/oil.ulaw|OIL|
|613|_male/on.ulaw|ON|
|001|_male/one.ulaw|ONE|
|904|_male/open.ulaw|OPEN|
|207|_male/operate.ulaw|OPERATE|
|352|_male/operation.ulaw|OPERATION|
|630|_male/operator.ulaw|OPERATOR|
|663|_male/oscar.ulaw|OSCAR|
|353|_male/other.ulaw|OTHER|
|740|_male/out.ulaw|OUT|
|355|_male/outer.ulaw|OUTER|
|773|_male/over.ulaw|OVER|
|356|_male/overcast.ulaw|OVERCAST|
|701|_male/p.ulaw|P|
|358|_male/p_m.ulaw|P.M.|
|208|_male/pair.ulaw|PAIR|
|671|_male/papa.ulaw|PAPA|
|209|_male/partial.ulaw|PARTIAL|
|361|_male/partially.ulaw|PARTIALLY|
|774|_male/pass.ulaw|PASS|
|974|_male/passed.ulaw|PASSED|
|966|_male/patch.ulaw|PATCH|
|362|_male/path.ulaw|PATH|
|364|_male/per.ulaw|PER|
|675|_male/percent.ulaw|PERCENT|
|914|_male/phone.ulaw|PHONE|
|932|_male/pico.ulaw|PICO|
|113|_male/pilot.ulaw|PILOT|
|967|_male/please.ulaw|PLEASE|
|611|_male/plus.ulaw|PLUS|
|674|_male/point.ulaw|POINT|
|968|_male/police.ulaw|POLICE|
|126|_male/port.ulaw|PORT|
|780|_male/position.ulaw|POSITION|
|096|_male/pound.ulaw|POUND|
|714|_male/power.ulaw|POWER|
|796|_male/practice.ulaw|PRACTICE|
|500|_male/prefix_fif.ulaw|FIF-|
|300|_male/prefix_thir.ulaw|THIR-|
|781|_male/press.ulaw|PRESS|
|935|_male/pressure.ulaw|PRESSURE|
|366|_male/private.ulaw|PRIVATE|
|975|_male/probe.ulaw|PROBE|
|159|_male/program.ulaw|PROGRAM|
|367|_male/programming.ulaw|PROGRAMMING|
|980|_male/pull.ulaw|PULL|
|977|_male/push.ulaw|PUSH|
|700|_male/q.ulaw|Q|
|670|_male/quebec.ulaw|QUEBEC|
|702|_male/r.ulaw|R|
|976|_male/radio.ulaw|RADIO|
|374|_male/rain.ulaw|RAIN|
|375|_male/raise.ulaw|RAISE|
|981|_male/range.ulaw|RANGE|
|376|_male/rate.ulaw|RATE|
|783|_male/ready.ulaw|READY|
|377|_male/rear.ulaw|REAR|
|378|_male/receive.ulaw|RECEIVE|
|744|_male/red.ulaw|RED|
|381|_male/release.ulaw|RELEASE|
|382|_male/remark.ulaw|REMARK|
|910|_male/remote.ulaw|REMOTE|
|745|_male/repair.ulaw|REPAIR|
|982|_male/repeat.ulaw|REPEAT|
|080|_male/repeater.ulaw|REPEATER|
|383|_male/rich.ulaw|RICH|
|384|_male/rig.ulaw|RIG|
|665|_male/right.ulaw|RIGHT|
|160|_male/rival.ulaw|RIVAL|
|385|_male/road.ulaw|ROAD|
|386|_male/roger.ulaw|ROGER|
|672|_male/romeo.ulaw|ROMER|
|239|_male/root.ulaw|ROOT|
|388|_male/route.ulaw|ROUTE|
|240|_male/run.ulaw|RUN|
|390|_male/runway.ulaw|RUNWAY|
|073|_male/s.ulaw|S|
|784|_male/safe.ulaw|SAFE|
|391|_male/sand.ulaw|SAND|
|392|_male/santa_clara.ulaw|SANTA CLARA|
|393|_male/saturday.ulaw|SATURDAY|
|246|_male/scatter.ulaw|SCATTER|
|394|_male/scattered.ulaw|SCATTERED|
|395|_male/second.ulaw|SECOND|
|635|_male/seconds.ulaw|SECONDS|
|247|_male/secure.ulaw|SECURE|
|396|_male/security.ulaw|SECURITY|
|397|_male/select.ulaw|SELECT|
|398|_male/september.ulaw|SEPTEMBER|
|410|_male/sequence.ulaw|SEQUENCE|
|723|_male/service.ulaw|SERVICE|
|885|_male/set.ulaw|SET|
|007|_male/seven.ulaw|SEVEN|
|017|_male/seventeen.ulaw|SEVENTEEN|
|249|_male/seventeenth.ulaw|SEVENTEENTH|
|280|_male/seventh.ulaw|SEVENTH|
|413|_male/severe.ulaw|SEVERE|
|289|_male/sex.ulaw|SEX|
|414|_male/sexy.ulaw|SEXY|
|301|_male/shop.ulaw|SHOP|
|415|_male/short.ulaw|SHORT|
|302|_male/shower.ulaw|SHOWER|
|416|_male/showers.ulaw|SHOWERS|
|765|_male/shut.ulaw|SHUT|
|417|_male/side.ulaw|SIDE|
|673|_male/sierra.ulaw|SIERRA|
|418|_male/sight.ulaw|SIGHT|
|006|_male/six.ulaw|SIX|
|016|_male/sixteen.ulaw|SIXTEEN|
|303|_male/sixteenth.ulaw|SIXTEENTH|
|304|_male/sixth.ulaw|SIXTH|
|423|_male/sleet.ulaw|SLEET|
|424|_male/slope.ulaw|SLOPE|
|983|_male/slow.ulaw|SLOW|
|795|_male/smoke.ulaw|SMOKE|
|425|_male/snow.ulaw|SNOW|
|790|_male/south.ulaw|SOUTH|
|984|_male/speed.ulaw|SPEED|
|427|_male/spray.ulaw|SPRAY|
|428|_male/squawk.ulaw|SQUAWK|
|431|_male/stall.ulaw|STALL|
|305|_male/star.ulaw|STAR|
|730|_male/start.ulaw|START|
|731|_male/stop.ulaw|STOP|
|433|_male/storm.ulaw|STORM|
|193|_male/suffix_ed.ulaw|-ED|
|210|_male/suffix_er.ulaw|-ER|
|948|_male/suffix_ing.ulaw|-ING|
|306|_male/suffix_ly.ulaw|-LY|
|915|_male/suffix_s.ulaw|-S|
|099|_male/suffix_teen.ulaw|-TEEN|
|441|_male/suffix_th.ulaw|-TH|
|060|_male/suffix_ty.ulaw|-TY|
|307|_male/suffix_y.ulaw|-Y|
|434|_male/sunday.ulaw|SUNDAY|
|308|_male/swap.ulaw|SWAP|
|725|_male/switch.ulaw|SWITCH|
|997|_male/system.ulaw|SYSTEM|
|081|_male/t.ulaw|T|
|681|_male/tango.ulaw|TANGO|
|435|_male/tank.ulaw|TANK|
|436|_male/target.ulaw|TARGET|
|437|_male/taxi.ulaw|TAXI|
|438|_male/telephone.ulaw|TELEPHONE|
|724|_male/temperature.ulaw|TEMPERATURE|
|010|_male/ten.ulaw|TEN|
|309|_male/tenth.ulaw|TENTH|
|318|_male/tenths.ulaw|TENTHS|
|440|_male/terminal.ulaw|TERMINAL|
|792|_male/test.ulaw|TEST|
|319|_male/than.ulaw|THAN|
|320|_male/thank.ulaw|THANK|
|978|_male/thank_you.ulaw|THANK YOU|
|442|_male/that.ulaw|THAT|
|024|_male/the.ulaw|THE|
|443|_male/the_long.ulaw|THE (long)|
|444|_male/the_short.ulaw|THE (short)|
|447|_male/third.ulaw|THIRD|
|013|_male/thirteen.ulaw|THIRTEEN|
|321|_male/thirteenth.ulaw|THIRTEENTH|
|451|_male/this.ulaw|THIS|
|065|_male/this_is.ulaw|THIS IS|
|644|_male/thousand.ulaw|THOUSAND|
|325|_male/thousandth.ulaw|THOUSANDTH|
|329|_male/thousandths.ulaw|THOUSANDTHS|
|003|_male/three.ulaw|THREE|
|331|_male/thunderstorm.ulaw|THUNDERSTORM|
|452|_male/thunderstorms.ulaw|THUNDERSTORMS|
|453|_male/thursday.ulaw|THURSDAY|
|338|_male/til.ulaw|'TIL|
|044|_male/time.ulaw|TIME|
|339|_male/time_out.ulaw|TIME OUT|
|732|_male/timer.ulaw|TIMER|
|455|_male/to.ulaw|TO|
|456|_male/today.ulaw|TODAY|
|055|_male/tomorrow.ulaw|TOMORROW|
|045|_male/tonight.ulaw|TONIGHT|
|985|_male/tool.ulaw|TOOL|
|457|_male/tornado.ulaw|TORNADO|
|458|_male/touchdown.ulaw|TOUCHDOWN|
|460|_male/tower.ulaw|TOWER|
|461|_male/traffic.ulaw|TRAFFIC|
|340|_male/transceive.ulaw|TRANSCEIVE|
|341|_male/transceiver.ulaw|TRANSCEIVER|
|462|_male/transmit.ulaw|TRANSMIT|
|463|_male/trim.ulaw|TRIM|
|464|_male/tuesday.ulaw|TUESDAY|
|465|_male/turbulance.ulaw|TURBULANCE|
|990|_male/turn.ulaw|TURN|
|343|_male/twelfth.ulaw|TWELFTH|
|012|_male/twelve.ulaw|TWELVE|
|351|_male/twentieth.ulaw|TWENTIETH|
|020|_male/twenty.ulaw|TWENTY|
|002|_male/two.ulaw|TWO|
|082|_male/u.ulaw|U|
|775|_male/under.ulaw|UNDER|
|682|_male/uniform.ulaw|UNIFORM|
|715|_male/unit.ulaw|UNIT|
|467|_male/unlimited.ulaw|UNLIMITED|
|468|_male/until.ulaw|UNTIL|
|650|_male/up.ulaw|UP|
|470|_male/use_noun.ulaw|USE (noun)|
|471|_male/use_verb.ulaw|USE (verb)|
|083|_male/v.ulaw|V|
|986|_male/valley.ulaw|VALLEY|
|357|_male/value.ulaw|VALUE|
|941|_male/valve.ulaw|VALVE|
|473|_male/variable.ulaw|VARIABLE|
|475|_male/verify.ulaw|VERIFY|
|683|_male/victor.ulaw|VICTOR
|476|_male/visibility.ulaw|VISIBILITY|
|360|_male/volt.ulaw|VOLT|
|750|_male/volts.ulaw|VOLTS|
|091|_male/w.ulaw|W|
|054|_male/wait.ulaw|WAIT|
|477|_male/wake.ulaw|WAKE|
|478|_male/wake_up.ulaw|WAKE UP|
|363|_male/warn.ulaw|WARN|
|480|_male/warning.ulaw|WARNING|
|481|_male/watch.ulaw|WATCH|
|365|_male/watt.ulaw|WATT|
|815|_male/watts.ulaw|WATTS|
|482|_male/way.ulaw|WAY|
|095|_male/weather.ulaw|WEATHER|
|484|_male/wednesday.ulaw|WEDNESDAY|
|913|_male/welcome.ulaw|WELCOME|
|793|_male/west.ulaw|WEST|
|691|_male/whiskey.ulaw|WHISKEY|
|912|_male/will.ulaw|WILL|
|368|_male/win.ulaw|WIN|
|487|_male/wind.ulaw|WIND|
|490|_male/with.ulaw|WITH|
|369|_male/write.ulaw|WRITE|
|491|_male/wrong.ulaw|WRONG|
|692|_male/x-ray.ulaw|X-RAY|
|092|_male/x.ulaw|X|
|093|_male/y.ulaw|Y|
|693|_male/yankee.ulaw|YANKEE|
|794|_male/yellow.ulaw|YELLOW|
|492|_male/yesterday.ulaw|YESTERDAY|
|370|_male/you.ulaw|YOU|
|987|_male/your.ulaw|YOUR|
|090|_male/z.ulaw|Z|
|988|_male/zed.ulaw|ZED|
|000|_male/zero.ulaw|ZERO|
|494|_male/zone.ulaw|ZONE|
|690|_male/zulu.ulaw|ZULU|
|979|_sndfx/shortpause.ulaw|_sound effect_|
|034|_sndfx/longpause.ulaw|_sound effect_|
|860|_sndfx/tic.ulaw|_sound effect_|
|870|_sndfx/toc.ulaw|_sound effect_|
|873|_sndfx/laser.ulaw|_sound effect_|
|881|_sndfx/whistle.ulaw|_sound effect_|
|882|_sndfx/phaser.ulaw|_sound effect_|
|883|_sndfx/train.ulaw|_sound effect_|
|891|_sndfx/explosion.ulaw|_sound effect_|
|892|_sndfx/crowd.ulaw|_sound effect_|
### Message Banks
|Slot|Path|Description|Contents|
|-|-|-|-|
|00|rpt/cw_id|CW ID (writes to rpt.conf)|Writes to idtalkover in rpt.conf; msgreader plays via `rpt playback \|m`|
|01|ids/initial_id_1|Initial ID #1|_empty_|
|02|ids/initial_id_2|Initial ID #2|_empty_|
|03|ids/initial_id_3|Initial ID #3|_empty_|
|04|ids/anxious_id|Anxious ID|_empty_|
|05|ids/pending_id_1|Pending ID #1|_empty_|
|06|ids/pending_id_2|Pending ID #2|_empty_|
|07|ids/pending_id_3|Pending ID #3|_empty_|
|08|ids/pending_id_4|Pending ID #4|_empty_|
|09|ids/pending_id_5|Pending ID #5|_empty_|
|10|ids/special_id|Special ID|_empty_|
|11|tails/tail_message_1|Tail Message #1|_empty_|
|12|tails/tail_message_2|Tail Message #2|_empty_|
|13|tails/tail_message_3|Tail Message #3|_empty_|
|14|tails/tail_message_4|Tail Message #4|_empty_|
|15|tails/tail_message_5|Tail Message #5|_empty_|
|16|tails/tail_message_6|Tail Message #6|_empty_|
|17|tails/tail_message_7|Tail Message #7|_empty_|
|18|tails/tail_message_8|Tail Message #8|_empty_|
|19|tails/tail_message_9|Tail Message #9|_empty_|
|20|custom/bulletin_board_1|Bulletin Board #1|_empty_|
|21|custom/bulletin_board_2|Bulletin Board #2|_empty_|
|22|custom/bulletin_board_3|Bulletin Board #3|_empty_|
|23|custom/bulletin_board_4|Bulletin Board #4|_empty_|
|24|custom/bulletin_board_5|Bulletin Board #5|_empty_|
|25|custom/demonstration_1|Demonstration Msg. #1|_empty_|
|26|custom/demonstration_2|Demonstration Msg. #2|_empty_|
|27|custom/demonstration_3|Demonstration Msg. #3|_empty_|
|28|custom/demonstration_4|Demonstration Msg. #4|_empty_|
|29|custom/demonstration_5|Demonstration Msg. #5|_empty_|
|30|custom/emergency_autodial_0|Emergency Auto Dialer #0|_empty_|
|31|custom/emergency_autodial_1|Emergency Auto Dialer #1|_empty_|
|32|custom/emergency_autodial_2|Emergency Auto Dialer #2|_empty_|
|33|custom/emergency_autodial_3|Emergency Auto Dialer #3|_empty_|
|34|custom/emergency_autodial_4|Emergency Auto Dialer #4|_empty_|
|35|custom/emergency_autodial_5|Emergency Auto Dialer #5|_empty_|
|36|custom/emergency_autodial_6|Emergency Auto Dialer #6|_empty_|
|37|custom/emergency_autodial_7|Emergency Auto Dialer #7|_empty_|
|38|custom/emergency_autodial_8|Emergency Auto Dialer #8|_empty_|
|39|custom/emergency_autodial_9|Emergency Auto Dialer #9|_empty_|
|40|custom/mailbox_0|Mailbox #0|_empty_|
|41|custom/mailbox_1|Mailbox #1|_empty_|
|42|custom/mailbox_2|Mailbox #2|_empty_|
|43|custom/mailbox_3|Mailbox #3|_empty_|
|44|custom/mailbox_4|Mailbox #4|_empty_|
|45|custom/mailbox_5|Mailbox #5|_empty_|
|46|custom/mailbox_6|Mailbox #6|_empty_|
|47|custom/mailbox_7|Mailbox #7|_empty_|
|48|custom/mailbox_8|Mailbox #8|_empty_|
|49|custom/mailbox_9|Mailbox #9|_empty_|
|50|rpt/litz_alert|Long Tone Zero (LiTZ) Alert|_empty_|
|51|custom/available_51|Available for Custom Messages|_empty_|
|52|custom/available_52|Available for Custom Messages|_empty_|
|53|custom/available_53|Available for Custom Messages|_empty_|
|54|custom/available_54|Available for Custom Messages|_empty_|
|55|custom/available_55|Available for Custom Messages|_empty_|
|56|custom/available_56|Available for Custom Messages|_empty_|
|57|custom/available_57|Available for Custom Messages|_empty_|
|58|custom/available_58|Available for Custom Messages|_empty_|
|59|custom/available_59|Available for Custom Messages|_empty_|
|60|weather/wx_severe_alert|Severe Weather Alert|"SEVERE WEATHER ALERT"|
|61|weather/wx_alert|Weather Alert|"WEATHER ALERT"|
|62|weather/space_geomag_minor|Space Weather: Geomag Minor|_auto-generated_|
|63|weather/space_geomag_moderate|Space Weather: Geomag Moderate|_auto-generated_|
|64|weather/space_geomag_strong|Space Weather: Geomag Strong|_auto-generated_|
|65|weather/space_radio_minor|Space Weather: Radio Minor|_auto-generated_|
|66|weather/space_radio_moderate|Space Weather: Radio Moderate|_auto-generated_|
|67|weather/space_radio_strong|Space Weather: Radio Strong|_auto-generated_|
|68|weather/space_solar_minor|Space Weather: Solar Minor|_auto-generated_|
|69|weather/space_solar_moderate|Space Weather: Solar Moderate|_auto-generated_|
|70|wx/temp|Weather: Temperature|_temperature_|
|71|wx/wind|Weather: Wind Conditions|_wind conditions_|
|72|wx/pressure|Weather: Barometric Pressure|_barometric pressure_|
|73|wx/humidity|Weather: Humidity|_humidity_|
|74|wx/windchill|Weather: Wind Chill|_wind chill_|
|75|wx/heatindex|Weather: Heat Index|_heat index_|
|76|wx/dewpt|Weather: Dew Point|_dew point_|
|77|wx/preciprate|Weather: Precipitation Rate|_precipitation rate_|
|78|wx/preciptotal|Weather: Precipitation Total|_precipitation total_|
|79|wx/uv_warning|UV Index Warning|_auto-generated_|
|80|rpt/empty|_Not Used_|"EMPTY"|
|81|custom/rptrism01|Repeaterism #1|Short transmissions|
|82|custom/rptrism02|Repeaterism #2|Think before transmitting|
|83|custom/rptrism03|Repeaterism #3|Pause between conversation handovers|
|84|custom/rptrism16|Repeaterism #16 (replaced #4)|Certain words, there are... OH, NO YOU DON'T!|
|85|custom/rptrism05|Repeaterism #5|Be courteous|
|86|custom/rptrism06|Repeaterism #6|Use simplex when possible|
|87|custom/rptrism07|Repeaterism #7|Use low power when possible|
|88|custom/rptrism08|Repeaterism #8|Support your local repeater club|
|89|custom/rptrism09|Repeaterism #9|Butting in is not nice|
|90|custom/rptrism10|Repeaterism #10|Blessed are those who listen|
|91|custom/rptrism11|Repeaterism #11|Watch what you say|
|92|custom/rptrism12|Repeaterism #12|One thought per transmission|
|93|custom/rptrism13|Repeaterism #13|State your purpose|
|94|custom/rptrism14|Repeaterism #14|When testing, say so, and be brief|
|95|custom/rptrism15|Repeaterism #15|Identify your station|
|96|rpt/net_in_one_minute|Net Countdown: 1 Minute|"NET IN ONE MINUTE"|
|97|rpt/net_in_five_minutes|Net Countdown: 5 Minutes|"NET IN FIVE MINUTES"|
|98|rpt/net_in_ten_minutes|Net Countdown: 10 Minutes|"NET IN TEN MINUTES"|
|99|rpt/net_in_fifteen_minutes|Net Countdown: 15 Minutes|"NET IN FIFTEEN MINUTES"|
# Footnotes
[^1]: These are high fidelity recordings from a Texas Instruments TMS5220 speech synthesizer, sourced from an Advanced Computer Controls (ACC) RC-850 controller, version 3.8 (late serial number).  Recordings were sourced using audio-in to a PC with Audacity; these are captured in μ-law companding algorithm 8-bit PCM format.
[^2]: Weather reporting requires account registration and use of an API key from [Weather Underground](https://www.weatherunderground.com/).
