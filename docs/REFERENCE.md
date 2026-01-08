# Script Reference

This document provides detailed technical reference for all 24 scripts in `app_rpt__ultra`. Each script's purpose, invocation method, configuration parameters, and usage examples are documented here.
## Script Operations
> [!NOTE]
> All scripts reference `/opt/app_rpt/config.ini` for both runtime and master configuration data. Should you make any edits to scripts within `/opt/app_rpt/bin/`, please be cognizant of any changes that may need to be carried over to `config.ini` accordingly!
### statekeeper.sh
#### BY INVOCATION ONLY
This script basically the magic and the heart of it all. The purpose of `statekeeper.sh` is to manage all of your system's personalities, or states, and effectively do so on demand or when conditions are met.\
\
States can be invoked in any number of ways:
- through the command line;
- through the internal scheduler;
- or using DTMF commands.
#### PERSONALITIES
Several states, or personalities, have been pre-programmed to suit your general day-to-day needs:
|State Name|Purpose|Behaviors|
|-|-|-|
|default|Default Mode|This is the default power-up state that generally cleans up any modifications from other states, and puts your system back to a pre-defined running state.<br />This reads values set to default in `config.ini` and performs a number of `sed` replacements, and reloads *Asterisk*.|
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
2026-01-07 20:00:00, 1999, 0.6s, 1, no, kerchunk, state_0
2026-01-07 20:00:10, 1999, 0.7s, 2, no, kerchunk, state_0
2026-01-07 20:00:20, 1999, 0.8s, 3, no-passive, kerchunk, state_0
2026-01-07 20:00:30, 1999, 5.2s, 0, no, normal, state_0
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
