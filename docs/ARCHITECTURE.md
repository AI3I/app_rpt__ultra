# System Architecture

## Understanding the Installation

While `install.sh` makes setup easy, understanding what happens under the hood helps with troubleshooting and customization. Here's the technical breakdown:

### Directory Structure

**What `install.sh` creates:**
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
├── backups/               # Automatic backups from `upgrade.sh`
└── config.ini             # Master configuration (NOT in git)

/etc/asterisk/rpt.conf     # Asterisk app_rpt config (NOT in git)
/usr/src/app_rpt__ultra/   # Git repository (source code)
```

**Why this structure?**
- `/opt/app_rpt/`: FHS-compliant location for add-on application packages
- Symlinks to `/var/lib/asterisk/sounds/`: *Asterisk* can find audio files without path changes
- Separation of code (`/usr/src`) from runtime (`/opt/app_rpt`): Clean upgrades via `git pull`

### User Account Configuration

**What `install.sh` does for the `asterisk` user:**
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
5. Updates `/etc/asterisk/rpt.conf` parameters via `sed`
6. Logs activity to `/var/log/app_rpt.log`

**Example: How `idkeeper.sh` works every minute:**
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

**Unlike cron-based scripts, `kerchunkd.sh` runs as a continuous daemon:**

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

**`config.ini` variables cascade through the system:**

```ini
# config.ini
MYNODE=1999                    # Your node number
KERCHUNK_ENABLE=1              # Enable kerchunk detection
KERCHUNK_MODE=passive          # Log only (no audio warnings)
SEVEREWEATHER=3                # Weather alert state (0-3)
ROTATEIIDS=1                   # Rotate initial IDs
```

**How scripts use `config.ini`:**
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
- `/etc/asterisk/rpt.conf`: *Asterisk* native configuration (complex, AST-specific)
- `/opt/app_rpt/config.ini`: Simple key=value format for bash scripts
- Separation of concerns: *Asterisk* config vs. script behavior

### What Happens During Upgrade

**`upgrade.sh` technical steps:**

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

The hub/child architecture allows you to manage multiple repeater sites from a central **hub node**, with **child nodes** automatically synchronizing configuration, weather data, and software versions. This is ideal for repeater networks, linked systems, or multi-site deployments.

#### Why Use Hub/Spoke Architecture?

**Real-world use cases:**

1. **Repeater Networks (3+ sites)**
   - Update one hub, all sites automatically sync
   - Single weather API key serves entire network
   - Consistent audio files and messages across all sites

2. **Linked Systems**
   - Hub at well-connected site with reliable internet
   - Child nodes at remote locations (mountain tops, rural sites)
   - Centralized configuration management

3. **Cost Optimization**
   - Weather Underground free tier: 500 calls/day
   - Hub makes 96 calls/day (every 15 min)
   - 10 child nodes = 960 calls/day (exceeds limit)
   - **Solution**: Hub fetches once, children sync = 96 calls/day total!

4. **Consistency & Compliance**
   - Ensure all nodes use same FCC-compliant IDs
   - Synchronized message updates (emergencies, net announcements)
   - Version control across entire network

#### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         HUB NODE                            │
│                    (FETCHLOCAL=0)                           │
│                                                             │
│  • Fetches weather from Weather Underground API            │
│  • Stores data in /opt/app_rpt/lib/wunderground.out       │
│  • Runs all scripts normally (weatherkeeper.sh, etc.)      │
│  • Acts as rsync server for child nodes                    │
│  • Master copy of config.ini and audio files               │
│                                                             │
└──────────────┬──────────────┬───────────────┬──────────────┘
               │              │               │
               │ rsync        │ rsync         │ rsync
               │ every 5min   │ every 5min    │ every 5min
               ▼              ▼               ▼
       ┌───────────┐  ┌───────────┐  ┌───────────┐
       │  CHILD 1  │  │  CHILD 2  │  │  CHILD 3  │
       │ (Node A)  │  │ (Node B)  │  │ (Node C)  │
       │           │  │           │  │           │
       │ Syncs:    │  │ Syncs:    │  │ Syncs:    │
       │ • Weather │  │ • Weather │  │ • Weather │
       │ • Sounds  │  │ • Sounds  │  │ • Sounds  │
       │ • Version │  │ • Version │  │ • Version │
       └───────────┘  └───────────┘  └───────────┘
```

#### What Gets Synchronized

`configkeeper.sh` (runs every 5 minutes on child nodes) syncs:

| Path | Content | Purpose |
|------|---------|---------|
| `/opt/app_rpt/lib/wunderground.out` | Weather data (JSON) | Cached Weather Underground API response |
| `/opt/app_rpt/sounds/wx/` | Weather audio files | Temperature, wind, pressure, etc. (TMS5220) |
| `/opt/app_rpt/sounds/weather/` | Space weather files | Geomagnetic storm alerts (G/S/R scales) |
| `/opt/app_rpt/sounds/tails/` | Tail messages | Custom announcements, weather alerts |
| `/opt/app_rpt/sounds/ids/` | Voice IDs (optional) | Synchronized callsign IDs |
| Version check | `common.sh` version | Triggers auto-upgrade when hub updates |

**What does NOT sync:**
- `/opt/app_rpt/config.ini` - Each node has unique settings (MYNODE, callsign)
- `/etc/asterisk/rpt.conf` - Node-specific *Asterisk* configuration
- `/opt/app_rpt/sounds/custom/` - Site-specific recordings

#### Configuration Examples

**Hub Node Setup (`config.ini`):**
```ini
# Hub node at headquarters with good internet
MYNODE=1999
FETCHLOCAL=0              # This is the hub (fetch from internet)
WUAPIKEY=abc123...        # Weather Underground API key
WUSTATION=KSTEXAS123     # Local weather station
NWSZONE=PAZ073            # NOAA alert zone
```

**Child Node Setup (`config.ini`):**
```ini
# Remote site on mountain top
MYNODE=2000
FETCHLOCAL=1                     # This is a child (fetch from hub)
FETCHPOINT=hub.example.com       # Hub hostname or IP
AUTOUPGRADE=1                    # Auto-upgrade when hub version changes

# No weather API key needed - uses hub's data
WUAPIKEY=empty
WUSTATION=empty
NWSZONE=PAZ073              # Can use same zone or different
```

#### How `configkeeper.sh` Works

**Every 5 minutes on child nodes:**
```bash
# 1. Check if child node
if [[ $FETCHLOCAL == 1 ]]; then
    # 2. Sync weather data from hub
    rsync -avz --timeout=30 \
        ${FETCHPOINT}:/opt/app_rpt/lib/wunderground.out \
        /opt/app_rpt/lib/wunderground.out

    # 3. Sync weather audio files
    rsync -avz --delete --timeout=30 \
        ${FETCHPOINT}:/opt/app_rpt/sounds/wx/ \
        /opt/app_rpt/sounds/wx/

    # 4. Sync space weather audio
    rsync -avz --delete --timeout=30 \
        ${FETCHPOINT}:/opt/app_rpt/sounds/weather/ \
        /opt/app_rpt/sounds/weather/

    # 5. Check hub version
    HUB_VER=$(ssh $FETCHPOINT "grep VERSION /opt/app_rpt/bin/common.sh")
    LOCAL_VER=$(grep VERSION /opt/app_rpt/bin/common.sh)

    # 6. Auto-upgrade if enabled and versions differ
    if [[ $AUTOUPGRADE == 1 ]] && [[ "$HUB_VER" != "$LOCAL_VER" ]]; then
        log "Hub version changed: $HUB_VER (was $LOCAL_VER), upgrading..."
        cd /usr/src/app_rpt__ultra
        git pull
        ./upgrade.sh --auto-yes
    fi
fi
```

**Output logged to `/var/log/app_rpt.log`:**
```
2026-01-07 21:00:01 [configkeeper] Syncing from hub hub.example.com
2026-01-07 21:00:02 [configkeeper] Weather data synced: 2.1KB
2026-01-07 21:00:03 [configkeeper] Audio files synced: 15 files, 234KB
2026-01-07 21:00:04 [configkeeper] Version check: v2.0.5 (current)
```

#### Management Workflows

**Upgrading the entire network:**
```bash
# 1. SSH to hub node
ssh hub.example.com

# 2. Upgrade hub
cd /usr/src/app_rpt__ultra
git pull
sudo ./upgrade.sh

# 3. Wait 5 minutes - child nodes detect version change
# 4. Verify children upgraded (check logs):
ssh child1.example.com "tail -50 /var/log/app_rpt.log | grep upgrade"
```

**Updating a custom tail message network-wide:**
```bash
# 1. On hub, record new message to slot 05
asterisk -rx "rpt localplay 1999 /opt/app_rpt/sounds/tails/tail_message_5"

# 2. Optionally sync tails/ directory (if you enable it in configkeeper.sh)
# Default: tails/ are NOT synced (site-specific)

# 3. To sync tails, edit configkeeper.sh on children:
# Add: rsync -avz ${FETCHPOINT}:/opt/app_rpt/sounds/tails/ /opt/app_rpt/sounds/tails/
```

**Monitoring sync status across network:**
```bash
# Check when each child last synced
for node in child1 child2 child3; do
    echo "=== $node ==="
    ssh $node "stat -c '%y' /opt/app_rpt/lib/wunderground.out"
done
```

#### Benefits of Hub/Child Architecture

| Benefit | Description | Example |
|---------|-------------|---------|
| **API Efficiency** | Single API call serves N nodes | 10 nodes = 1 API key, 96 calls/day (vs 960) |
| **Consistency** | All nodes identical software/audio | Emergency message update in seconds |
| **Centralized Mgmt** | One place to update everything | `upgrade.sh` on hub → auto-upgrades 10 children |
| **Reduced Complexity** | Children don't need API keys | Remote mountain sites need no internet config |
| **Automatic Failover** | If sync fails, children use last good data | Hub offline? Children keep announcing last weather |
| **Version Control** | Guaranteed version consistency | No "oops, forgot to upgrade site #7" |
| **Bandwidth Savings** | rsync only transfers changed files | Weather data: ~2KB every 15min vs ~15KB audio regen |

#### Troubleshooting Hub/Child Sync

**Child not syncing from hub:**
```bash
# Check SSH connectivity
ssh hub.example.com "echo Hub is reachable"

# Test rsync manually
rsync -avz hub.example.com:/opt/app_rpt/lib/wunderground.out /tmp/test.out

# Check FETCHLOCAL setting
grep FETCHLOCAL /opt/app_rpt/config.ini

# Check configkeeper.sh logs
grep configkeeper /var/log/app_rpt.log | tail -20
```

**Version mismatch (child won't auto-upgrade):**
```bash
# Check AUTOUPGRADE setting
grep AUTOUPGRADE /opt/app_rpt/config.ini

# Check git repository status
cd /usr/src/app_rpt__ultra && git status

# Manually upgrade
cd /usr/src/app_rpt__ultra && git pull && sudo ./upgrade.sh
```

**High bandwidth usage:**
```bash
# Check rsync behavior (should use --delete for efficiency)
# View configkeeper.sh rsync commands
cat /opt/app_rpt/bin/configkeeper.sh | grep rsync

# Monitor rsync transfers
watch -n 60 'ls -lh /opt/app_rpt/sounds/wx/'
```

#### Advanced: Cascading Hubs

For very large networks (20+ nodes), you can create **regional hubs**:

```
        Primary Hub (Internet-connected)
               │
       ┌───────┴───────┐
       │               │
  Regional Hub     Regional Hub
   (West Coast)    (East Coast)
       │               │
   ┌───┴───┐       ┌───┴───┐
   │   │   │       │   │   │
  N1  N2  N3      N4  N5  N6
```

**Primary hub** (`FETCHLOCAL=0`): Fetches from internet
**Regional hubs** (`FETCHLOCAL=1`, `FETCHPOINT=primary.hub.com`): Sync from primary
**Child nodes** (`FETCHLOCAL=1`, `FETCHPOINT=regional.hub.com`): Sync from regional hub

This reduces load on primary hub and provides geographic redundancy.

## Key Takeaways

Understanding this architecture helps you:
- **Troubleshoot**: Know which script handles what function
- **Customize**: Edit scripts knowing how they interact
- **Extend**: Add new scripts following the same patterns
- **Debug**: Check logs, cron output, systemd status
- **Optimize**: Tune timing, disable unused features

The magic is in the integration—bash scripts, Asterisk CLI, systemd services, and cron jobs working together to create a sophisticated repeater controller from simple, readable components.

