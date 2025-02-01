# Introduction
_**app_rpt__ultra**_ was designed to be the ultimate controller experience for [Asterisk](https://www.asterisk.org/) [AllStarLink app_rpt](https://www.allstarlink.org/)!  Built on the history and capabilities of standalone repeater controllers from the 1980s-2000s, this platform was designed to combine the art and technology of today with yesteryear.  Some of the features included were takeaways and inspirations from controllers similar to Advanced Computer Controls, Link Communications, Computer Automation Technology and FF Systems.

## How does it work?
All of the frameworks were written in Bash (Bourne again shell) using scripts that are called by _app_rpt_.  The intent was to modify as little as possible so frameworks were relatively immutable and could survive any code updates to Asterisk and _app_rpt_.  Most scripts are called either from within Asterisk or from local cron jobs.

## Key Features
- Management of repeater states or personalities
- Rotating identifier and tail messages
- An advanced message editor with the ability to program messages, courtesy tones and telemetry via DTMF
- A vocabulary of 877 words and sound effects with dozens of pre-defined phrases
- Weather alerting system, powered by NOAA NWS alerts
- Reporting weather conditions, powered by Weather Underground
- Full integration with Asterisk AllStarLink app_rpt without code modification

# Installation
## System Requirements
> [!WARNING]
> Only [AllStarLink 3](https://allstarlink.github.io/) is supported; functionality for previous versions of _app_rpt_ have been removed.

## Download Codebase

## Local Changes

### Installing local software
You will need a couple of packages for successful execution of all scripts within the suite.  Namely, **sudo** and **jq** will be required, if not already present.

`apt install sudo jq -y`

### Modifying the _asterisk_ account
_**app_rpt__ultra**_ will require required unfettered use of Asterisk's native local account, _asterisk_, and requires an interactive shell with sudo access.
As superuser root, you should change the shell accordingly:

`usermod -s /bin/bash -G sudo asterisk`

### Ensuring sudo access without passwords
Modify _/etc/sudoers_ to ensure **NOPASSWD** is added to the sudo rule:
```
# Allow members of group sudo to execute any command without a password
%sudo	ALL=(ALL:ALL) NOPASSWD: ALL
```
### Create local directories
You will need to put your configurations and directories into a local repo:

`mkdir -p /opt/app_rpt/{bin,lib,sounds}`

### Remove local sound directories to make way for the vocabulary bank

`rm -rf /var/lib/asterisk/sounds /usr/share/asterisk/sounds`

### Copy provided sounds to _/opt/app_rpt/sounds_

`cp -Rf sounds/* /opt/app_rpt/sounds/`

### Copy executable scripts to _/opt/app_rpt/bin_

`cp -Rf bin/* /opt/app_rpt/bin/`

### Create a symbolic links for the predefined vocabulary bank

`ln -s /opt/app_rpt/sounds /var/lib/asterisk/sounds`

### Ensure permissions are properly set

`chmod -Rf asterisk:asterisk /opt/app_rpt`

### Configure crontab for _asterisk_ user

`sudo su - asterisk`

`crontab -e`

Use the following for your crontab:
```
0 0 * * *      /opt/app_rpt/bin/datekeeper.sh      # Produce today's date for readback
0 0 * * *      /opt/app_rpt/bin/datadumper.sh      # Purge old recordings
*/15 * * * *   /opt/app_rpt/bin/weatherkeeper.sh   # Produce current weather conditions
* * * * *      /opt/app_rpt/bin/timekeeper.sh      # Produce the current time for readback
* * * * *      /opt/app_rpt/bin/idkeeper.sh        # Manage all system IDs
* * * * *      /opt/app_rpt/bin/tailkeeper.sh      # Manage all tail messages
* * * * *      /opt/app_rpt/bin/weatheralert.sh    # Poll for (severe) weather alerts
```

### Copy **rpt.conf** template to _/etc/asterisk_ and configure to your liking

Copy configuration templates

`cp rpt.conf /etc/asterisk/rpt.conf`

`cp extensions_custom.conf /etc/asterisk/extensions_custom.conf`

Edit configuration

`nano -w /etc/asterisk/rpt.conf`

> [!TIP]
> 1. Replace all instances of `%MYCALL%` within the file with your call sign
> 2. Replace `%MYNODE%` to match your AllStarLink node number
> 3. Be sure to check your **duplex** and **rxchannel** values to ensure they align with desired operation
> 4. _Do not change_ the **idrecording=voice_id** parameter; this is overwritten by _idkeeper.sh_ which you will learn more about later.

### Copy config.ini template to _/opt/app_rpt/_ and configure

`cp config.ini /opt/app_rpt`

> [!CAUTION]
> At minimum, `%MYNODE%` toward the top of the file should be replaced with your AllStarLink node number; failure to set this will cause nearly all scripts to fail!

### Setup temporary voice identifier from vocabulary bank

For example, and assuming our node number is 504380, we want to use word choices from the vocabulary bank, and want it to say "_This is A I 3 I repeater._"  We can achieve this by concatenating several files together to produce our ID, as follows:

`cd /opt/app_rpt/sounds/_male; cat this_is.ulaw a.ulaw i.ulaw 3.ulaw i.ulaw repeater.ulaw > /opt/app_rpt/sounds/voice_id.ulaw`

The message is written and can be tested through manual invocation by using: `rpt localplay 504380 voice_id`

### Set permissions unilaterally

`chown -Rf asterisk:asterisk /opt/app_rpt`

### Restart Asterisk

`systemctl restart asterisk`
