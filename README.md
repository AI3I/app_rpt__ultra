# Introduction
_**app_rpt__ultra**_ was designed to be the ultimate controller experience for [Asterisk](https://www.asterisk.org/) [AllStarLink app_rpt](https://www.allstarlink.org/)!  Built on the history and capabilities of standalone repeater controllers from the 1980s-2000s, this platform was designed to combine the art and technology of today with yesteryear.  Some of the features included were takeaways and inspirations from controllers similar to Advanced Computer Controls, Link Communications, Computer Automation Technology and FF Systems.

## How does it work?
All of the frameworks were written in Bash (Bourne again shell) using scripts that are called by _app_rpt_.  The intent was to modify as little as possible so frameworks were relatively immutable and could survive any code updates to Asterisk and _app_rpt_.  Most scripts are called either from within Asterisk or from local cron jobs.

## Key Features
- Management of repeater states or personalities
- Rotating identifier and tail messages
- An advanced message editor with the ability to program messages, courtesy tones and telemetry via DTMF
- A vocabulary of 877 words and sound effects with dozens of pre-defined phrases; these are high fidelity recordings from a Texas Instruments TSP5220 speech synthesizer from an Advanced Computer Controls (ACC) RC-850, version 3.8 controller
- Weather alerting system, powered by NOAA NWS alerts
- Reporting weather conditions, powered by Weather Underground (requires account registration and use of an API key)
- Full integration with Asterisk AllStarLink app_rpt without any code modification

# Installation
## System Requirements
> [!WARNING]
> Only [AllStarLink 3](https://allstarlink.github.io/) is supported; functionality for previous versions of _app_rpt_ have been removed.

## Download Codebase

`git clone https://github.com/AI3I/app_rpt__ultra.git`

`cd app_rpt__ultra`

### Create local directory to store _**app_rpt__ultra**_

`mkdir -p /opt/app_rpt`

### Remove local sound directories to make way for the vocabulary bank

`rm -rf /var/lib/asterisk/sounds /usr/share/asterisk/sounds`

### Copy provided sounds to _/opt/app_rpt/sounds_

`cp -Rf sounds/* /opt/app_rpt/sounds/`

### Copy executable scripts to _/opt/app_rpt/bin_

`cp -Rf bin/* /opt/app_rpt/bin/`

### Create a symbolic links for the predefined vocabulary bank

`ln -s /opt/app_rpt/sounds /var/lib/asterisk/sounds`

## Local Changes

### Installing local software
You will need a couple of packages for successful execution of all scripts within the suite.  Namely, **jq** will be required, if not already present.

`apt install jq -y`

### Modifying the _asterisk_ account
_**app_rpt__ultra**_ will require required unfettered use of Asterisk's native local account, _asterisk_, and requires an interactive shell with _sudo_ access.
As superuser root, you should change the shell accordingly (and include other groups, including: _dialout_, _audio_, and _plugdev_):

`usermod -s /bin/bash -G sudo,dialout,audio,plugdev asterisk`

### Ensuring sudo access without passwords
Modify _/etc/sudoers_ to ensure **NOPASSWD** is added to the sudo rule:
```
# Allow members of group sudo to execute any command without a password
%sudo	ALL=(ALL:ALL) NOPASSWD: ALL
```
### Ensure permissions are properly set

`chmod -Rf asterisk:asterisk /opt/app_rpt /etc/asterisk`

### Configure crontab for _asterisk_ user

`sudo su - asterisk`

`crontab -e`

Use the following for your crontab:
```
# apt_rpt__ultra crontab
0 0 * * *      /opt/app_rpt/bin/datekeeper.sh      # Produce today's date for readback
0 0 * * *      /opt/app_rpt/bin/datadumper.sh      # Purge old recordings
*/15 * * * *   /opt/app_rpt/bin/weatherkeeper.sh   # Produce current weather conditions
* * * * *      /opt/app_rpt/bin/timekeeper.sh      # Produce the current time for readback
* * * * *      /opt/app_rpt/bin/idkeeper.sh        # Manage all system IDs
* * * * *      /opt/app_rpt/bin/tailkeeper.sh      # Manage all tail messages
* * * * *      /opt/app_rpt/bin/weatheralert.sh    # Poll for (severe) weather alerts
```

### Copy **rpt.conf** and **extensions_custom.conf** templates to _/etc/asterisk_ and edit to your liking

> [!TIP]
> 1. Replace all instances of `%MYCALL%` within the file with your call sign
> 2. Replace `%MYNODE%` to match your AllStarLink node number
> 3. Be sure to check your **duplex** and **rxchannel** values to ensure they align with desired operation (i.e. with _usbradio.conf_ or _simpleusb.conf_)
> 4. _Do not change_ the **idrecording=voice_id** parameter; this is overwritten by _idkeeper.sh_ which you will learn more about later.

Copy configuration templates:

`cp rpt.conf /etc/asterisk/rpt.conf`

`cp extensions_custom.conf /etc/asterisk/extensions_custom.conf`

In order to start with the basics, you can do a _sed_ replacement:

```
sed -i s/%MYNODE%/1999/g /etc/asterisk/rpt.conf
sed -i s/%MYCALL%/MYC4LL/g /etc/asterisk/rpt.conf
```

Edit configurations to your liking

`nano -w /etc/asterisk/rpt.conf`


### Copy config.ini template to _/opt/app_rpt/_ and configure

> [!CAUTION]
> At minimum, `%MYNODE%` should be replaced with your AllStarLink node number; failure to set this will cause nearly all scripts to fail!

`cp config.ini /opt/app_rpt`

`sed -i s/%MYNODE%/1999/g /etc/asterisk/rpt.conf`

### Setup temporary voice identifier from vocabulary bank

For example, and assuming our node number is 1999 and the callsign is MYC4LL, we want to use word choices from the vocabulary bank, and want it to say "_This is M Y C 4 L L repeater._"  We can achieve this by concatenating several files together to produce our ID, as follows:

`cd /opt/app_rpt/sounds/_male; cat this_is.ulaw m.ulaw y.ulaw c.ulaw 4.ulaw l.ulaw l.ulaw repeater.ulaw > /opt/app_rpt/sounds/voice_id.ulaw`

The message is written and can be tested through manual invocation by using:

`rpt localplay 1999 voice_id`

## Wrapping up

### Set permissions unilaterally

`chown -Rf asterisk:asterisk /opt/app_rpt`

### Set the initial date for readback

`sudo su - asterisk`

`/opt/app_rpt/bin/datekeeper.sh`

### Restart Asterisk

`systemctl restart asterisk`

# Operation
Now that you've set up the basics and have legal IDs, it's time to dive deeper into the general operation and behavior of _**app_rpt__ultra**_.  You have configured cron jobs that are now managing general operations of your system, and by periodically dispatching scripts to do our bidding.
## Script Operations
> [!NOTE]
> All scripts reference _/opt/app_rpt/config.ini_ for runtime and master configuration data.  Should you make any edits to scripts within _/opt/app_rpt/bin_, be cognizant of any changes that may need to be reflected in _config.ini_ accordingly!
### statekeeper.sh
#### BY INVOCATION ONLY
This script basically the magic and the heart of it all.  The purpose of _statekeeper.sh_ is to manage all of your system's personalities, or states, and to modify those on demand.  States can be invoked in any number of ways:  through the command line, using DTMF, or through the internal scheduler.
Several default states have been pre-programmed to take on situational personalities:
|State Name|Purpose|Behaviors|
|-|-|-|
|default|Default Mode|This is the default power-up state that generally cleans up any modifications from other states, and puts your system back to a pre-defined running state.|
|standard|Standard Mode|Ideal if you prefer a static state and don't leverage daytime or nighttime modes.|
|daytime|Daytime Mode|Ideal for daytime operations.|
|nighttime|Nighttime Mode|Ideal for nighttime operations.|
|net|Net Mode|Changes behaviors for net, including brief IDs, courtesy tone change, and relaxed timers.|
|tactical|Tactical Mode|Ideal for tactical operations with adjusted timers and courtesy tone.|
|weatheralert|Weather Alert|This announces "weather alert" as a tail message, relaxes timers, but maintains normal operations.|
|severeweather|Severe Weather Mode|This changes the courtesy tone, announces "severe weather alert" for a tail message, suppresses timers, and sends a two-tone page alerting of severe weather.|
|stealth|Stealth Mode|With the exception of required CW ID, this suppresses all telemetry including voice synthesis, courtesy tones, cuts hang timers, and disables the scheduler.|
|litzalert|Long Tone Zero (LiTZ) Alert|This generates two-tone pages and announcements when the LiTZ command is executed.|
|clock|Grandfather Clock|This emulates the CAT-1000 grandfather clock and can be called through the scheduler at the top of every hour.|

### idkeeper.sh
#### CRONTAB: every minute
This script makes calls into Asterisk to determine current repeater and identifier states, and based upon _config.ini_ and pre-defined behaviors in _statekeeper.sh_ will determine what identifiers it plays, and when.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|SPECIALID|0 or 1 (_boolean_)|Whether the Special ID is toggled on or not|
|ROTATEIIDS|0 or 1 (_boolean_)|Whether Initial IDs are rotated|
|ROTATEPIDS|0 or 1 (_boolean_)|Whether Pending IDs are rotated|
|INITIALID|1,2,3|Overide with specific Initial ID|
|PENDINGID|1,2,3,4,5|Override with specific Pending ID|

### tailkeeper.sh
#### CRONTAB: every minute
This follows _statekeeper.sh_ behavior and adjusts tail messages based upon operational condition and weather conditions.  By default, it will rotate in messages for current time and local temperature, if Weather Underground is configured.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|ENABLETAIL|0 or 1 (_boolean_)|Whether the tail messages are enabled or not|
|ENABLETIME|0 or 1 (_boolean_)|Whether periodic time announcements are given in tail messages or not|
|ENABLETEMP|0 or 1 (_boolean_)|Whether periodic temperature readings are given in tail messages or not (requires Weather Underground configuration)|
|ROTATETMSG|0 or 1 (_boolean_)|Whether to rotate tail messages or not|
|TAILMSG|1,2,3,4,5,6,7,8,9|Override with specific tail message|

### weatheralert.sh
#### CRONTAB: every minute
This monitors NOAA National Weather Service alerts, if configured for your NWS zone, and will trigger _statekeeper.sh_ to change to a weather alert or severe weather alert, if enabled.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|NWSZONE|XXX000|The default value is invalid and should be replaced with your local NWS zone: [NWS Public Forecast Zones](https://www.weather.gov/gis/publiczones)|
|NWSFILE|/opt/app_rpt/lib/nwsalerts.out|File where weather alerting data is kept for parsing|
|SEVEREWEATHER|0,1,2,3|_**0**_ deactivated; _**1**_ incidcates a _severe_ weather alert; _**2**_ indicates a weather alert; _**3**_ indicates all conditions are normal|
|RTWXALERT|tails/weather_alert|File path of tail message to be played for routine weather alert|
|SVWXALERT|tails/severe_weather_alert|File path of tail message to be played for severe weather alert|

### weatherkeeper.sh
#### CRONTAB: every 15 minutes
This polls Weather Underground (if you setup an API key) to poll for weather station data in your region.  It will generate temperature, humdity, wind speed and direction, et al., which can be called by invocation.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|FETCHLOCAL|0 or 1 (_boolean_)|Whether to pull data from a local system (i.e. hub system that collates your weather data); default is _0_|
|WUAPIKEY|_empty_|Should be populated with your [Weather Underground API Key](https://www.weatherunderground.com/)|
|WUSTATION|_empty_|ID of a Weather Underground station that provides you with local weather data|
|WUOUTPUT|/opt/app_rpt/lib/wunderground.out|File where raw JSON data from Weather Underground raw is kept for parsing|

### datadumper.sh
#### CRONTAB: midnight daily
This purges old recordings after they have aged by the defined period in the script.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|RETENTION|_integer_|The number of days to keep recordings (default is _**60**_ days).|

### datekeeper.sh
#### CRONTAB: midnight daily
This generates date messages once daily for playback by invocation.  (_There are no configurable options._)

### timekeeper.sh
#### CRONTAB: every minute
This generates time messages every minute for playback either in tail messages or by invocation.  (_There are no configurable options._)
