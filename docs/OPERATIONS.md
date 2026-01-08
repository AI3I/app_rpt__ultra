# Practical Usage Guide

Now that you understand the architecture, let's explore how to actually **use** the system in real-world scenarios.

## Common DTMF Commands

Here are the most frequently used commands you'll want to memorize or program into macros:

### System State Control
```
*C900#  - Default operations (reset to normal)
*C901#  - Standard operations
*C902#  - Daytime operations
*C903#  - Nighttime operations
*C904#  - Net operations (brief, relaxed timers)
*C905#  - Tactical operations
*C906#  - Weather alert mode
*C907#  - Severe weather mode (aggressive)
*C908#  - Stealth mode (no telemetry except CW ID)
*C909#  - LiTZ alert (page control operators)
*C910#  - Grandfather clock
```

### Message Playback (Slot System)
```
*83XX#  - Play message slot XX (00-99)

Common slots:
*8300#  - Slot 00: CW ID
*8370#  - Slot 70: Current temperature
*8371#  - Slot 71: Wind conditions
*8379#  - Slot 79: UV index warning (if active)
*8396#  - Slot 96: "Net in 1 minute"
*8397#  - Slot 97: "Net in 5 minutes"
*8398#  - Slot 98: "Net in 10 minutes"
*8399#  - Slot 99: "Net in 15 minutes"
```

### ID and Tail Message Control
```
*C801#  - Enable Special ID
*C802#  - Disable Special ID
*C803#  - Enable tail messages
*C804#  - Disable tail messages
*C805#  - Enable ID rotation
*C806#  - Disable ID rotation
```

## Daily Operation Scenarios

### Scenario 1: Starting Your Day (Morning Routine)

**Goal**: Switch from nighttime to daytime operations

```bash
# Via DTMF:
*C902#    # Switch to daytime mode

# Or via command line (remote management):
ssh ai3i@repeater.example.com "sudo -u asterisk /opt/app_rpt/bin/statekeeper.sh daytime"
```

**What happens automatically:**
- Tail messages switch to daytime rotation
- Timers adjust for active operations
- Temperature announcements enabled
- System state changes to "daytime"

### Scenario 2: Preparing for a Net

**Goal**: Switch to net mode, announce countdown warnings

**15 minutes before net:**
```
*8399#    # Play "Net in 15 minutes"
```

**10 minutes before net:**
```
*8398#    # Play "Net in 10 minutes"
```

**5 minutes before net:**
```
*8397#    # Play "Net in 5 minutes"
```

**1 minute before net:**
```
*8396#    # Play "Net in 1 minute"
```

**At net start:**
```
*C904#    # Switch to net mode
```

**What net mode does:**
- Changes courtesy tone to "net tone"
- Suppresses telemetry (time, temperature)
- Relaxes timers (longer hang time, no timeout)
- Keeps tail messages brief

**After net ends:**
```
*C900#    # Return to default operations
```

### Scenario 3: Weather Alert Response

**When NOAA alert detected**, weatheralert.sh automatically:
1. Detects alert via API poll (every minute)
2. Switches to weather alert or severe weather mode
3. Changes tail message to announce alert
4. (Severe only) Sends two-tone page

**Manual weather alert invocation:**
```
*C906#    # Weather alert mode (routine)
*C907#    # Severe weather mode (aggressive)
```

**Check current weather:**
```
*8370#    # Temperature
*8371#    # Wind
*8372#    # Pressure
*8373#    # Humidity
```

**Check space weather:**
```
*8362#    # Geomagnetic storm (if active)
*8365#    # Radio blackout (if active)
*8368#    # Solar radiation (if active)
```

**Return to normal after alert clears:**
```
*C900#    # weatheralert.sh will auto-clear when alert expires
```

### Scenario 4: Tactical Operations

**Goal**: Minimal telemetry, distinct courtesy tone, emergency-ready

```
*C905#    # Tactical mode
*C804#    # Disable tail messages (optional - already suppressed)
```

**What tactical mode does:**
- Tactical courtesy tone
- Suppresses time/temp announcements
- Keeps essential IDs only
- Adjusts timers for rapid communication

**If complete radio silence needed (except CW ID):**
```
*C908#    # Stealth mode
```

**Return to normal:**
```
*C900#    # Default operations
```

## Utility Scripts Reference

These user-facing utilities aren't in cron but are available for manual invocation or DTMF integration:

### sayip.sh
**Purpose**: Announces IP addresses for remote management

**Usage:**
```bash
/opt/app_rpt/bin/sayip.sh [interface]

# Examples:
/opt/app_rpt/bin/sayip.sh eth0     # LAN IP address
/opt/app_rpt/bin/sayip.sh wlan0    # WiFi IP address
/opt/app_rpt/bin/sayip.sh tun0     # VPN IP address
/opt/app_rpt/bin/sayip.sh          # All configured interfaces
```

**DTMF Integration (add to rpt.conf):**
```ini
[functions]
9001=cmd,/opt/app_rpt/bin/sayip.sh eth0
9002=cmd,/opt/app_rpt/bin/sayip.sh wlan0
```

**What it does:**
1. Reads IP address from `ip addr show`
2. Converts to TMS5220 speech: "ethernet address 192.168.1.100"
3. Plays via `rpt localplay`

**Use case**: You're on the road, need to SSH into your repeater, but don't remember the IP. Key *9001# and listen!

### speaktext.sh
**Purpose**: Convert arbitrary text to TMS5220 speech

**Usage:**
```bash
/opt/app_rpt/bin/speaktext.sh "text to speak" [output_file]

# Examples:
/opt/app_rpt/bin/speaktext.sh "repeater offline for maintenance"
# Plays immediately

/opt/app_rpt/bin/speaktext.sh "testing testing one two three" /opt/app_rpt/sounds/custom/test.ulaw
# Generates file only (no playback)
```

**How it works:**
1. Parses text word-by-word
2. Looks up each word in vocabulary.txt (877 words)
3. Concatenates matching .ulaw files
4. Falls back to spelling unknown words letter-by-letter

**Use case**: Quick custom announcements without recording audio

**Limitations**:
- Only works with TMS5220 vocabulary (877 words)
- Unknown words spelled out (sounds robotic)
- Numbers must be written out ("one two three" not "123")

**Better for custom messages**: Record your voice with msgwriter.sh

### gpio.sh
**Purpose**: Control GPIO pins for external hardware (relays, indicators, sensors)

**Usage:**
```bash
/opt/app_rpt/bin/gpio.sh <pin> <on|off|read>

# Examples:
/opt/app_rpt/bin/gpio.sh 17 on      # Turn on GPIO17 (relay/LED)
/opt/app_rpt/bin/gpio.sh 17 off     # Turn off GPIO17
/opt/app_rpt/bin/gpio.sh 27 read    # Read GPIO27 status (sensor)
```

**DTMF Integration for remote control:**
```ini
[functions]
9101=cmd,/opt/app_rpt/bin/gpio.sh 17 on    # Activate relay 1
9102=cmd,/opt/app_rpt/bin/gpio.sh 17 off   # Deactivate relay 1
9111=cmd,/opt/app_rpt/bin/gpio.sh 27 on    # Activate relay 2
9112=cmd,/opt/app_rpt/bin/gpio.sh 27 off   # Deactivate relay 2
```

**Real-world applications:**
- **Repeater site control**: Turn on/off equipment (fans, heaters, transmitters)
- **Status indicators**: LED panel showing repeater mode
- **Security**: Door locks, camera triggers
- **Sensors**: Read door status, temperature sensors, battery voltage

**Hardware requirements:**
- Raspberry Pi or similar with GPIO pins
- Relay modules for switching AC/DC loads
- LEDs with current-limiting resistors
- Sensors with appropriate interfaces

**Example: Remote fan control**
```bash
# Check temperature
TEMP=$(asterisk -rx "rpt stats 504381" | grep -i temperature | awk '{print $NF}')

# If over 80°F, turn on fan via GPIO
if [[ ${TEMP%%.*} -gt 80 ]]; then
    /opt/app_rpt/bin/gpio.sh 17 on
    /opt/app_rpt/bin/speaktext.sh "cooling fan activated"
fi
```

### wireless.sh
**Purpose**: Announce WiFi connection status and signal strength

**Usage:**
```bash
/opt/app_rpt/bin/wireless.sh [interface]

# Examples:
/opt/app_rpt/bin/wireless.sh wlan0    # Specific interface
/opt/app_rpt/bin/wireless.sh          # Default wireless interface
```

**DTMF Integration:**
```ini
[functions]
9003=cmd,/opt/app_rpt/bin/wireless.sh
```

**What it announces:**
- Connected/disconnected status
- SSID name
- Signal strength (excellent/good/fair/poor)
- Link quality percentage

**Use case**: Remote site monitoring - is the wireless backhaul still connected?

**Output example**: "wireless connected to repeater backhaul signal strength excellent"

## Integration Scenarios

### Scenario: Automated Weather Response

**Goal**: Automatically switch modes based on NOAA alerts

**How it works (already configured):**
1. `weatheralert.sh` polls NOAA every minute
2. Detects alerts for your NWSZONE
3. Classifies severity (routine vs. severe)
4. Calls `statekeeper.sh` automatically:
   - Routine: `statekeeper.sh weatheralert`
   - Severe: `statekeeper.sh severeweather` (with two-tone page)

**What you hear:**
- **Routine alert**: Tail message changes to "weather alert", normal operations
- **Severe alert**: Two-tone page (330Hz + 569Hz), tail message "severe weather alert", timers relaxed

**Manual testing:**
```bash
# Simulate weather alert
sudo -u asterisk /opt/app_rpt/bin/statekeeper.sh weatheralert

# Simulate severe weather
sudo -u asterisk /opt/app_rpt/bin/statekeeper.sh severeweather

# Return to normal
sudo -u asterisk /opt/app_rpt/bin/statekeeper.sh default
```

### Scenario: Scheduled State Changes

**Goal**: Automatically switch between daytime/nighttime modes

**Method 1: *Asterisk* scheduler (`rpt.conf`)**
```ini
[schedule]
; At 0700 local time, switch to daytime
0 7 * * * = C902    ; Daytime mode

; At 2200 local time, switch to nighttime
0 22 * * * = C900   ; Default (or use C903 for nighttime)
```

**Method 2: Cron job**
```bash
# Add to asterisk user crontab:
0 7 * * *    /opt/app_rpt/bin/statekeeper.sh daytime
0 22 * * *   /opt/app_rpt/bin/statekeeper.sh default
```

**Why use scheduler vs. cron?**
- **Scheduler**: Integrated with *Asterisk*, respects local timezone, can be overridden via DTMF
- **Cron**: Independent of *Asterisk*, survives *Asterisk* restarts, more flexible

### Scenario: Custom Message on Net Start

**Goal**: Play custom "net starting" message before switching to net mode

**Steps:**
1. **Record custom message:**
   ```bash
   # From a phone (DTMF)
   *88025#    # Start recording to slot 25 (demonstration_1)
   # Speak your message
   #          # Hang up to finish
   ```

2. **Create macro in `rpt.conf`:**
   ```ini
   [macro]
   9900=*8325#*C904#    ; Play slot 25, then switch to net mode
   ```

3. **Use it:**
   ```
   *9900#    # Plays your custom message, then enters net mode
   ```

### Scenario: Multi-Site Weather Data Sharing

**Goal**: Hub fetches weather data once, child nodes use cached data

**Hub node configuration (`config.ini`):**
```ini
FETCHLOCAL=0           # Hub fetches from Weather Underground
WUAPIKEY=your_key      # Your Weather Underground API key
WUSTATION=KPAPITTS1    # Local weather station
```

**Child node configuration (`config.ini`):**
```ini
FETCHLOCAL=1                     # Pull from hub
FETCHPOINT=hub.example.com       # Hub hostname/IP
AUTOUPGRADE=1                    # Auto-upgrade when hub version changes
```

**What happens:**
- Hub runs `weatherkeeper.sh` every 15 minutes, fetches from WU API
- Hub stores data in `/opt/app_rpt/lib/wunderground.out`
- Child nodes run `configkeeper.sh` every 5 minutes
- `configkeeper.sh` syncs `/opt/app_rpt/lib/` from hub via `rsync`
- Child nodes use cached weather data (no API calls)
- All nodes announce same weather data
- API rate limits: 1 request serves 10 nodes!

**Benefits:**
- Single API key for entire network
- Consistent weather data across sites
- Centralized version control
- Auto-upgrade capability

### Scenario: Remote Site Monitoring via DTMF

**Goal**: Check remote repeater site status from any radio

**Custom monitoring script (`/opt/app_rpt/bin/sitestatus.sh`):**
```bash
#!/bin/bash
source /opt/app_rpt/bin/common.sh

# Announce site name
asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/custom/site_name"

# IP address
/opt/app_rpt/bin/sayip.sh eth0

# Wireless status
/opt/app_rpt/bin/wireless.sh wlan0

# Temperature
asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/wx/temp"

# System uptime
UPTIME_DAYS=$(awk '{print int($1/86400)}' /proc/uptime)
/opt/app_rpt/bin/speaktext.sh "uptime ${UPTIME_DAYS} days"
```

**DTMF integration (rpt.conf):**
```ini
[functions]
9999=cmd,/opt/app_rpt/bin/sitestatus.sh    # Site status report
```

**Usage**: Key *9999# from any radio to hear complete site status!

## Customization Recipes

### Recipe 1: Add Your Own Courtesy Tone

**Goal**: Create a custom courtesy tone using Audacity or other audio editor

**Steps:**
1. **Record/edit audio**:
   - Keep it short (< 500ms)
   - Export as 8kHz, mono, µlaw (.ulaw)

2. **Upload to repeater:**
   ```bash
   scp my_custom_ct.ulaw ai3i@repeater.example.com:/tmp/
   ssh ai3i@repeater.example.com "sudo mv /tmp/my_custom_ct.ulaw /opt/app_rpt/sounds/custom/ct99.ulaw"
   ```

3. **Configure in config.ini:**
   ```ini
   CTCUSTOM=ct99    # Your custom tone
   ```

4. **Use in statekeeper.sh** or apply manually:
   ```bash
   /opt/app_rpt/bin/ctkeeper.sh ct99
   ```

### Recipe 2: Create a Custom Tail Message

**Goal**: Add your own voice announcement as tail message

**Method 1: Via DTMF (easiest)**
```
*88011#    # Record to slot 11 (tail_message_1)
# Speak: "Welcome to the AI3I repeater system"
#        # Hang up
```

**Method 2: Via command line**
```bash
# Record from phone, upload .ulaw file
scp my_tail.ulaw ai3i@repeater.example.com:/tmp/
ssh ai3i@repeater.example.com "sudo mv /tmp/my_tail.ulaw /opt/app_rpt/sounds/tails/tail_message_1.ulaw"
```

**Enable rotation:**
```ini
# config.ini
ROTATETMSG=1     # Enable tail rotation
TAILMSG=1        # Use tail_message_1
```

### Recipe 3: Add Space Weather to Tail Rotation

**Goal**: Include space weather alerts in tail message rotation

**Edit tailkeeper.sh** (around line 50):
```bash
# Add after temperature/time logic:
if [[ -f "${SOUNDS}/weather/space_geomag_minor.ulaw" ]]; then
    asterisk -rx "rpt playback ${MYNODE} ${SOUNDS}/weather/space_geomag_minor"
elif [[ -f "${SOUNDS}/weather/space_radio_moderate.ulaw" ]]; then
    asterisk -rx "rpt playback ${MYNODE} ${SOUNDS}/weather/space_radio_moderate"
fi
```

**Or use DTMF manually when storm detected:**
```
*8362#    # Play geomagnetic storm alert (if active)
```

### Recipe 4: GPIO-Based Emergency Broadcast

**Goal**: Physical panic button triggers emergency broadcast

**Hardware**: Button connected to GPIO23 (pull-down resistor)

**Monitoring script** (`/opt/app_rpt/bin/panic_monitor.sh`):
```bash
#!/bin/bash
while true; do
    # Read GPIO23
    STATUS=$(/opt/app_rpt/bin/gpio.sh 23 read)

    if [[ "$STATUS" == "HIGH" ]]; then
        # Panic button pressed!
        asterisk -rx "rpt localplay 504381 /opt/app_rpt/sounds/custom/emergency_broadcast"

        # Send two-tone page
        asterisk -rx "rpt localplay 504381 |it330,569,3000"

        # Switch to tactical mode
        /opt/app_rpt/bin/statekeeper.sh tactical

        # Wait for button release
        sleep 5
    fi

    sleep 1
done
```

**Run as systemd service** (survives reboots):
```bash
# Create /etc/systemd/system/panic-monitor.service
sudo systemctl enable panic-monitor
sudo systemctl start panic-monitor
```

## Quick Troubleshooting

**Problem**: Temperature not announcing
```bash
# Check if weatherkeeper is running
sudo crontab -u asterisk -l | grep weatherkeeper

# Check if API key configured
grep WUAPIKEY /opt/app_rpt/config.ini

# Manually run to see errors
sudo -u asterisk /opt/app_rpt/bin/weatherkeeper.sh

# Check generated file
ls -lh /opt/app_rpt/sounds/wx/temp.ulaw
```

**Problem**: IDs not rotating
```bash
# Check rotation enabled
grep ROTATEIIDS /opt/app_rpt/config.ini    # Should be 1

# Check cron job
sudo crontab -u asterisk -l | grep idkeeper

# Manually trigger rotation
sudo -u asterisk /opt/app_rpt/bin/idkeeper.sh

# Check which ID is active
grep idrecording /etc/asterisk/rpt.conf
```

**Problem**: Kerchunk detection not working
```bash
# Check service running
sudo systemctl status kerchunkd

# Check logs
tail -f /var/log/app_rpt.log | grep kerchunk
tail -f /var/log/kerchunk_stats.log

# Verify configuration
grep ^KERCHUNK /opt/app_rpt/config.ini
```

**Problem**: DTMF commands not working
```bash
# Check macro defined
grep "^9000=" /etc/asterisk/rpt.conf

# Test from Asterisk CLI
asterisk -rx "rpt fun 504381 *C900"

# Check function vs. macro syntax
# Functions: single action
# Macros: multiple actions (needs macro= section)
```

## Summary: Your Toolbox

You now have:
- ✅ **10 system states** for different operations
- ✅ **100 message slots** for dynamic content
- ✅ **Automated weather** monitoring and alerts
- ✅ **Space weather** integration
- ✅ **Kerchunk detection** (passive logging or active deterrence)
- ✅ **Custom courtesy tones** and messages
- ✅ **GPIO control** for site automation
- ✅ **Network utilities** (IP address, wireless status)
- ✅ **Distributed architecture** for multi-site deployments
- ✅ **DTMF remote control** for everything

**Next**: Dive into the detailed [Script Reference](REFERENCE.md) to understand each component in depth!

