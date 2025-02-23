# Introduction
_**app_rpt__ultra**_ was designed to be the ultimate controller experience for [Asterisk](https://www.asterisk.org/) [AllStarLink app_rpt](https://www.allstarlink.org/)!  Built on the history and capabilities of standalone repeater controllers from the 1980s-2000s, this platform was designed to combine the art and technology of today with yesteryear.  Some of the features included were takeaways and inspirations from controllers similar to Advanced Computer Controls, Link Communications, Computer Automation Technology and FF Systems.
## How does it work?
All of the frameworks were written in Bash (Bourne again shell) using scripts that are called by _app_rpt_.  The intent was to modify as little as possible so frameworks were relatively immutable and could survive any code updates to Asterisk and _app_rpt_.  Most scripts are called either from within Asterisk or from local cron jobs.
## Key Features
- Management of repeater states or personalities;
- Rotating identifier and tail messages;
- An advanced message editor with the ability to program messages, courtesy tones and telemetry via DTMF;
- A vocabulary of 877 words and sound effects with dozens of pre-defined phrases[^1];
- Weather alerting system, powered by NOAA NWS alerts;
- Reporting weather conditions, powered by Weather Underground[^2];
- Full integration with Asterisk AllStarLink app_rpt without any code modification!
# Installation
## System Requirements
> [!WARNING]
> Only [AllStarLink 3](https://allstarlink.github.io/) is supported; functionality for previous versions of _app_rpt_ have been removed.
## Download Codebase
```
mkdir -p /usr/src
cd /usr/src
git clone https://github.com/AI3I/app_rpt__ultra.git
cd app_rpt__ultra
```
### Create local directory to store _**app_rpt__ultra**_
```
mkdir -p /opt/app_rpt /opt/asterisk /etc/asterisk/custom
```
### Remove local sound directories to make way for the vocabulary bank
```
rm -rf /var/lib/asterisk/sounds /usr/share/asterisk/sounds
```
### Copy provided sounds to _/opt/app_rpt/sounds_
```
cp -Rf app_rpt/sounds/* /opt/app_rpt/sounds/
```
### Copy executable scripts to _/opt/app_rpt/bin_
```
cp -Rf app_rpt/bin/* /opt/app_rpt/bin/
```
### Create symbolic links for the vocabulary bank
```
ln -s /opt/app_rpt/sounds /var/lib/asterisk/sounds
ln -s /opt/app_rpt/sounds /usr/share/asterisk/sounds
```
## System Changes
### Install local software
You will need **jq**, a JSON parser, for successful execution of all scripts within the suite.
```
apt install jq -y
```
### Modify the _asterisk_ account
_**app_rpt__ultra**_ will require required unfettered use of Asterisk's native local account, _asterisk_, and requires an interactive shell with _sudo_ access.
```
usermod -s /bin/bash -G sudo,dialout,audio,plugdev asterisk
```
> [!CAUTION]
> The _dialout_, _audio_, and _plugdev_ groups are important for stable operation in ASL3.  Should you remove access to those groups, USB audio and control interfaces running under the _asterisk_ account **will not work**!
### Ensure _sudo_ has access without passwords
Modify _/etc/sudoers_ to ensure **NOPASSWD** is added to the sudo rule:
```
# Allow members of group sudo to execute any command without a password
%sudo	ALL=(ALL:ALL) NOPASSWD: ALL
```
### Ensure permissions are properly set
```
chmod -Rf asterisk:asterisk /etc/asterisk /opt/asterisk /opt/app_rpt /usr/src/app_rpt__ultra
```
### Configure crontab for _asterisk_ user
```
sudo su - asterisk
crontab -e
```
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
### Copy configuration templates
> [!TIP]
> 1. Replace `%MYNODE%` to match your AllStarLink node number (_we used **1999** as an example_)
> 2. Replace all instances of `%MYCALL%` within the file with your call sign (_we used **MYC4LL** as an example_)
> 3. Be sure to check your **duplex** and **rxchannel** values to ensure they align with desired operation (i.e. with _usbradio.conf_ or _simpleusb.conf_)
> 4. _Do not change_ the **idrecording=voice_id** parameter in _rpt.conf_; this is overwritten by _idkeeper.sh_, which you will learn more about later.

Copy configuration templates:
```
cp asterisk/rpt.conf /etc/asterisk/rpt.conf
cp asterisk/extensions_custom.conf /etc/asterisk/custom/extensions.conf
cp config.ini /opt/app_rpt/config.ini
```
In order to start with the basics, you can do a _sed_ replacement:
```
sed -i s/%MYNODE%/1999/g /etc/asterisk/rpt.conf /opt/app_rpt/config.ini
sed -i s/%MYCALL%/MYC4LL/g /etc/asterisk/rpt.conf
```
### Setup temporary voice identifier from vocabulary bank
Let us assume our voice ID will say "_This is M Y C 4 L L repeater._"  We can achieve this by concatenating several files together to produce our ID, as follows:
```
cd /opt/app_rpt/sounds/_male
cat this_is.ulaw m.ulaw y.ulaw c.ulaw 4.ulaw l.ulaw l.ulaw repeater.ulaw \
> /opt/app_rpt/sounds/voice_id.ulaw
```
The message is written and can be tested through manual invocation by using:
```
sudo asterisk -rx "rpt localplay 1999 voice_id"
```
## Wrapping up
### Set permissions unilaterally, again, just for good measure
```
sudo chown -Rf asterisk:asterisk /etc/asterisk /opt/app_rpt /opt/asterisk
```
### Set the initial date for readback
```
sudo su - asterisk
/opt/app_rpt/bin/datekeeper.sh
```
### Restart Asterisk
```
sudo systemctl restart asterisk
```
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
This polls Weather Underground[^2] to poll for weather station data in your region.  Several conditions, such as temperature, humdity, wind speed and direction, et al., are generated which can be called by invocation.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|FETCHLOCAL|0 or 1 (_boolean_)|Whether to pull data from a local system (i.e. hub system that collates your weather data).<br />The default is _**0**_.|
|WUAPIKEY|_empty_|Should be populated with your Weather Underground API key.[^2]|
|WUSTATION|_empty_|ID of a Weather Underground station that provides you with local weather data.[^2]|
|WUOUTPUT|/opt/app_rpt/lib/wunderground.out|Explicit file path where raw JSON data is kept for parsing by **jq**.|
### datadumper.sh
#### CRONTAB: midnight daily
This purges old recordings after they have aged by the defined period in the script.
|Variables|Values|Description & Behaviors (config.ini)|
|-|-|-|
|RETENTION|_integer_|The number of days to keep recordings.<br />The default is _**60**_ days and recordings are stored in _/opt/asterisk_ with status logs.|
### datekeeper.sh
#### CRONTAB: midnight daily
This generates date messages once daily for playback by invocation.\
_There are no configurable options._
### timekeeper.sh
#### CRONTAB: every minute
This generates time messages every minute for playback either in tail messages or by invocation.\
_There are no configurable options._
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
|00|_Forced CW ID_|Forced CW ID|_empty_|
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
|51|tails/weather_alert|Weather Alert|"WEATHER ALERT"|
|52|tails/severe_weather_alert|Severe Weather Alert|"SEVERE WEATHER ALERT"|
|53|rpt/net_in_one_minute|Impending Net (1 minute)|"NET IN ONE MINUTE"|
|54|rpt/net_in_five_minutes|Impending Net (5 minutes)|"NET IN FIVE MINUTES"|
|55|rpt/net_in_ten_minutes|Impending Net (10 minutes)|"NET IN TEN MINUTES"|
|56|rpt/empty|_Not Used_|"EMPTY"|
|57|rpt/empty|_Not Used_|"EMPTY"|
|58|rpt/empty|_Not Used_|"EMPTY"|
|59|rpt/empty|_Not Used_|"EMPTY"|
|60|rpt/empty|_Not Used_|"EMPTY"|
|61|rpt/empty|_Not Used_|"EMPTY"|
|62|rpt/empty|_Not Used_|"EMPTY"|
|63|rpt/empty|_Not Used_|"EMPTY"|
|64|rpt/empty|_Not Used_|"EMPTY"|
|65|rpt/empty|_Not Used_|"EMPTY"|
|66|rpt/empty|_Not Used_|"EMPTY"|
|67|rpt/empty|_Not Used_|"EMPTY"|
|68|rpt/empty|_Not Used_|"EMPTY"|
|69|rpt/empty|_Not Used_|"EMPTY"|
|70|wx/temp|Weather: Temperature|_temperature_|
|71|wx/wind|Weather: Wind Conditions|_wind conditions_|
|72|wx/pressure|Weather: Barometric Pressure|_barometric pressure_|
|73|wx/humidity|Weather: Humidity|_humidity_|
|74|wx/windchill|Weather: Wind Chill|_wind chill_|
|75|wx/heatindex|Weather: Heat Index|_heat index_|
|76|wx/dewpt|Weather: Dew Point|_dew point_|
|77|wx/preciprate|Weather: Precipitation Rate|_precipitation rate_|
|78|wx/preciptotal|Weather: Precipitation Total|_precipitation total_|
|79|rpt/empty|_Not Used_|"EMPTY"|
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
|96|rpt/empty|_Not Used_|"EMPTY"|
|97|rpt/empty|_Not Used_|"EMPTY"|
|98|rpt/empty|_Not Used_|"EMPTY"|
|99|rpt/empty|_Not Used_|"EMPTY"|
## Message Management
### msgreader.sh
This reads back messages stored in the message table listed above.
#### EXAMPLES
* We want to hear the current temperature outside:
```
msgreader.sh 70
```
* We want to hear Repeaterism #16 because it's darn funny:
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
This script can write messages into slots using the vocabulary and character tables listed above.
> [!NOTE]
> 1. Slot _**00** is special_ and is for the Forced CW ID, which overwrites the values in the _**idtalkover**_ parameter.
> 2. Slots **01** through **50** are customizable through the message writer, while slots **51** through **99** are pre-programmed and cannot be overwritten by this tool.
> 3. Character `D` delimits the slot from the message, and `*` delimits each character or vocabulary word.

#### EXAMPLES
* We want to write CW ID into slot 00 with "MYC4LL":
```
msgwriter.sh 00D61*93*23*04*53*53
```
* We want to write a voice message into slot 04 for the Anxious ID that reads back "MYC4LL REPEATER":
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
# Footnotes
[^1]: These are high fidelity recordings from a Texas Instruments TSP5220 speech synthesizer, sourced from an Advanced Computer Controls (ACC) RC-850 controller, version 3.8 (late serial number).  Recordings were sourced using audio-in to a PC with Audacity; these are captured in μ-law companding algorithm 8-bit PCM format.
[^2]: Weather reporting requires account registration and use of an API key from [Weather Underground](https://www.weatherunderground.com/).
