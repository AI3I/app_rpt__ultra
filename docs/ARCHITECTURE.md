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
6. Logs activity to `/opt/app_rpt/log/app_rpt.log`

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
StandardOutput=append:/opt/app_rpt/log/app_rpt.log
StandardError=append:/opt/app_rpt/log/app_rpt.log

[Install]
WantedBy=multi-user.target
```

**How it integrates:**
1. Polls `asterisk -rx "rpt stats"` every 1 second (vs. cron's 1 minute)
2. Tracks transmission durations in real-time
3. Logs to `/opt/app_rpt/log/kerchunk_stats.log` (CSV format)
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
# install.sh replaces Asterisk's en/ language directory with symlinks
# ASL3 uses astdatadir=/usr/share/asterisk, so sound lookups resolve as:
#   /usr/share/asterisk/sounds/en/<file>
# Both standard search paths are covered:
ln -sf /opt/app_rpt/sounds /usr/share/asterisk/sounds/en
ln -sf /opt/app_rpt/sounds /var/lib/asterisk/sounds/en

# Why symlink en/ specifically (not the parent)?
# - Asterisk prepends the language code (default: en) to all sound lookups
# - Replacing en/ with our sounds dir makes rpt/goodmorning resolve to
#   /opt/app_rpt/sounds/rpt/goodmorning.ulaw (TMS5220), not Allison Smith
# - The original en/ directory is preserved as en.allison_backup/
# - Scripts that use absolute paths (/opt/app_rpt/sounds/wx/temp) are unaffected
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

**`upgrade.sh` steps:**

1. **Version check** — compares `/opt/app_rpt/VERSION` with the release's
   `VERSION` file. Reinstalling the same version needs `--force`.
2. **Backup** — `/opt/app_rpt/backups/upgrade_backup_<timestamp>/` gets
   `config.ini`, `bin/`, `lib/`, `rpt.conf`, the asterisk crontab and the old
   and new version numbers.
3. **Sound layout** — if `/opt/app_rpt/sounds` is still a real directory,
   `migrate-lang.sh` moves it to the `rp` layout. Nothing is deleted: the old
   directory is kept as `backups/sounds_premigration_<timestamp>/`.
4. **Config migration** — a new `config.ini` is built from the release
   template with every existing non-empty setting carried over (paths stay
   release-managed). On a hub, every `backups/<node>/config.ini` is migrated
   the same way.
5. **Scripts** — `common.sh` first (and checked), then `bin/*.sh` and the
   utilities in `util/`. Each file is written next to its destination and
   renamed into place, so a script running during the upgrade keeps its old
   copy. The `kerchunkd` service and log rotation are updated too.
6. **Sounds** — release sound directories are synced; `ids/`, `tails/` and
   `custom/` are never touched.
7. **Finish** — validation, ownership, `/opt/app_rpt/VERSION` is written, and
   the release is staged in `/opt/app_rpt/src` for child nodes.

**Rollback:** if script installation or validation fails, `config.ini`,
`bin/` and `lib/` are restored from the backup and the version is reset.

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
               │ hourly (:05) │ hourly (:05)  │ hourly (:05)
               ▼              ▼               ▼
       ┌───────────┐  ┌───────────┐  ┌───────────┐
       │  CHILD 1  │  │  CHILD 2  │  │  CHILD 3  │
       │ (Node A)  │  │ (Node B)  │  │ (Node C)  │
       │           │  │           │  │           │
       │ Syncs:    │  │ Syncs:    │  │ Syncs:    │
       │ • Configs │  │ • Configs │  │ • Configs │
       │ • Scripts │  │ • Scripts │  │ • Scripts │
       │ • Sounds  │  │ • Sounds  │  │ • Sounds  │
       │ • Version │  │ • Version │  │ • Version │
       └───────────┘  └───────────┘  └───────────┘
```

#### What Gets Synchronized

`configkeeper.sh` runs **hourly at :05** on every node from the `rpt.conf`
scheduler (a `[schedule]` entry calls macro `9920`, which runs the `cmd` function
`C9920`; see `rpt.conf.example`). It
exits immediately unless `FETCHLOCAL=1`, so on a hub it does nothing. A child
pulls from its hub (`FETCHPOINT`):

| Hub source | Child destination | How |
|------------|-------------------|-----|
| `backups/<node>/config.ini` | `/opt/app_rpt/config.ini` | Applied only when the hub copy changes |
| `backups/<node>/rpt.conf` | `/etc/asterisk/rpt.conf` | Applied only when the hub copy changes |
| `backups/<node>/manager.conf` | `/etc/asterisk/manager.conf` | Applied only when the hub copy changes |
| `backups/<node>/extensions.conf` | `/etc/asterisk/custom/extensions.conf` | Applied only when the hub copy changes |
| `backups/<node>/allmon3.ini` | `/etc/allmon3/allmon3.ini` | Applied only when changed (if allmon3 is installed) |
| `/opt/app_rpt/bin/`, `/opt/app_rpt/util/` | same paths | Mirrored |
| `/opt/app_rpt/sounds/rpt/` (incl. `nodenames/`) | same path | Mirrored |
| `backups/<node>/sounds/ids/` | `/opt/app_rpt/sounds/ids/` | Copied, never mirrored (an empty hub copy can't wipe a node's IDs) |
| `/opt/app_rpt/src/` | same path | Only for an auto-upgrade (below) |

**The hub's `/opt/app_rpt/backups/<node>/` directory is the source of truth for
each child.** Edit a child's files there; the child applies them within the hour.

**What does NOT sync:** `tails/`, `custom/`, `wx/`, `weather/` and the
Weather Underground data; those are per node.

#### How `configkeeper.sh` Works

- **State is preserved.** `statekeeper.sh` and `weatheralert.sh` edit the
  local `rpt.conf`/`config.ini` on every state change (daytime, nighttime,
  net, alerts). Hub copies are staged in `/opt/app_rpt/lib/hubsync/` and
  applied only when their checksum differs from the last applied one, so an
  unchanged hub copy never undoes a state change. To force a re-apply, delete
  `/opt/app_rpt/lib/hubsync/*.applied` on the child.
- **Reloads only when needed.** Asterisk (`module reload`) and allmon3 are
  reloaded only when a config file was actually applied.
- **Failures don't stop the sync.** Each transfer is attempted; failures are
  logged and counted, the rest still run, and the script exits 1 at the end.
- **Auto-upgrade.** With `AUTOUPGRADE=1`, if the hub's `/opt/app_rpt/VERSION`
  differs from the child's, the child pulls the hub's staged release from
  `/opt/app_rpt/src/` and runs `src/upgrade.sh --force --auto-yes`, keeping its
  settings. Hubs stage that release whenever `upgrade.sh` or `install.sh` runs
  on them. Asterisk is not restarted by an upgrade.
- **SSH.** All hub connections run as root with `BatchMode`, so a missing key
  or host-key prompt fails fast instead of hanging.

**Logged to `/opt/app_rpt/log/app_rpt.log`:**
```
[2026-11-10 21:53:12] [38620] Applied updated rpt.conf from node504380
[2026-11-10 21:53:12] [38620] Config sync from node504380 complete
```

#### Management Workflows

**Upgrading the entire network:**
```bash
# 1. On the hub, from a checkout of the new release (bump VERSION for each
#    release: children only auto-upgrade when the hub's VERSION changes)
sudo ./upgrade.sh
#    -> installs the release, stages it in /opt/app_rpt/src for children, and
#       migrates each backups/<node>/config.ini to the current format

# 2. Children with AUTOUPGRADE=1 upgrade themselves at the next :05.
#    Verify on a child:
grep -aE "Auto-upgrade|Config sync" /opt/app_rpt/log/app_rpt.log | tail -3

# 3. Children with AUTOUPGRADE=0: on the child,
sudo rsync -a hub:/opt/app_rpt/src/ /opt/app_rpt/src/
sudo bash /opt/app_rpt/src/upgrade.sh --force --auto-yes
```

**Updating a tail message:** tails are per node and are not synced. Record
the message on each node with `msgwriter.sh` (tail slots 11-19, e.g.
`15D<codes>` for `tails/tail_message_5`).

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
grep configkeeper /opt/app_rpt/log/app_rpt.log | tail -20
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

