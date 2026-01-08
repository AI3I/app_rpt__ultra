# Introduction
`app_rpt__ultra` was designed to be the ultimate controller experience for *Asterisk* and *AllStarLink*! Built on the history and capabilities of standalone repeater controllers from the 1980s-2000s, this platform combines the art and technology of today with yesteryear. Some of the features included were takeaways and inspirations from controllers similar to Advanced Computer Controls, Link Communications, Computer Automation Technology and FF Systems.

## How does it work?
All of the frameworks were written in Bash (Bourne again shell) using scripts that are called by `app_rpt`. The intent was to modify as little as possible so frameworks were relatively immutable and could survive any code updates to *Asterisk* and `app_rpt`. Most scripts are called either from within *Asterisk* (through invocation in `rpt.conf`) or from local cron jobs.

## Key Features
- Management of repeater states or personalities;
- Rotating identifier and tail messages;
- An advanced message editor with the ability to program messages, courtesy tones and telemetry via DTMF;
- A vocabulary of 877 high-fidelity TMS5220 words and sound effects with dozens of pre-defined phrases;
- Weather alerting system, powered by NOAA NWS alerts;
- Reporting weather conditions, powered by Weather Underground;
- Space weather monitoring with NOAA SWPC integration (geomagnetic storms, radio blackouts, solar radiation);
- Intelligent kerchunk detection with passive monitoring (statistics) and active deterrence (polite reminders);
- Comprehensive statistics logging for transmission pattern analysis;
- Full integration with *Asterisk* and *AllStarLink* `app_rpt` without any code modification!

# Installation

## System Requirements
> [!WARNING]
> Only [AllStarLink 3](https://allstarlink.github.io/) is supported; functionality for previous versions of `app_rpt` and interoperability with HamVoIP have been removed.

> [!NOTE]
> Debian 12 (bookworm) and Debian 13 (trixie) have been tested, along with Asterisk 20 and 22.

## Quick Install
The installer script handles all setup automatically, including:
- Installing dependencies (`jq`)
- Creating directories and copying files
- Configuring the `asterisk` user account
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

> [!NOTE]
> Weather condition reporting requires a free account and API key from [Weather Underground](https://www.weatherunderground.com/). The system will work without it, but weather telemetry features will be unavailable.

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
1. Review `/etc/asterisk/rpt.conf` and verify **duplex** and **rxchannel** settings match your configuration (`usbradio.conf` or `simpleusb.conf`)
2. The **idrecording=voice_id** parameter should remain unchanged; it is managed by `idkeeper.sh`
3. Restart *Asterisk*: `sudo systemctl restart asterisk`

# Documentation

This project includes comprehensive documentation organized by topic. Choose the guide that matches your needs:

## 📖 Documentation Guide

### [System Architecture](docs/ARCHITECTURE.md)
**Technical deep-dive into how `app_rpt__ultra` works under the hood**

Learn about:
- Directory structure and why it's organized this way
- User account configuration (`asterisk` user, `dialout` group, SSH)
- Cron job integration with complete listing
- Systemd services (`kerchunkd` daemon)
- *Asterisk* integration (CLI commands, message slots, audio flow)
- Sound file management (symlinks, TMS5220 concatenation)
- Configuration management (`config.ini` cascade)
- Upgrade process internals (technical breakdown)
- Distributed architecture (hub/child, rsync, auto-upgrade)

**Best for:** Understanding what `install.sh` does, troubleshooting issues, customizing the installation, deploying multi-site architectures

---

### [System Maintenance](docs/MAINTENANCE.md)
**Upgrading, repairing, and uninstalling your installation**

Learn about:
- Upgrading your installation with `upgrade.sh`
- Hub-spoke upgrade workflows (automatic child node updates)
- System health checks and repair with `repair.sh`
- Uninstalling cleanly with `uninstall.sh`
- Backup management and version control

**Best for:** Keeping your system up-to-date, fixing configuration drift, managing distributed deployments

---

### [Practical Operations](docs/OPERATIONS.md)
**Daily usage, real-world scenarios, and customization recipes**

Learn about:
- Common DTMF commands quick reference
- Daily operation scenarios (morning routine, net prep, weather alerts, tactical ops)
- Utility scripts (`sayip.sh`, `speaktext.sh`, `gpio.sh`, `wireless.sh`)
- Integration scenarios with code examples
- Customization recipes (custom tones, messages, GPIO buttons)
- Quick troubleshooting guide

**Best for:** Day-to-day operation, learning DTMF commands, implementing custom features, solving common problems

---

### [Script Reference](docs/REFERENCE.md)
**Complete technical reference for all 24 scripts**

Learn about:
- **Operation scripts**: `statekeeper.sh`, `idkeeper.sh`, `tailkeeper.sh`, `weatheralert.sh`, `weatherkeeper.sh`, `configkeeper.sh`, `kerchunkd.sh`
- **Maintenance scripts**: `datadumper.sh`, `datekeeper.sh`, `timekeeper.sh`
- **Message management**: `msgreader.sh`, `msgwriter.sh`
- **Courtesy tone management**: `ctwriter.sh`, `ctkeeper.sh`
- Invocation methods (cron vs systemd vs manual)
- Configuration parameters for each script
- Examples and use cases

**Best for:** Understanding what each script does, configuring advanced features, debugging script behavior

---

### [Message Tables](docs/TABLES.md)
**Complete reference for vocabulary, message slots, and CW characters**

Includes:
- **CW Characters table**: DTMF keypad mapping for Morse code
- **Word Vocabulary**: All 877 TMS5220 words with phonetic spelling
- **Message Banks**: Complete slot-to-file mapping (slots 00-99)

**Best for:** Programming custom messages, understanding available vocabulary, planning message slot assignments

---

## Quick Links

- **First time user?** Start with [Installation](#installation) above, then read [Practical Operations](docs/OPERATIONS.md)
- **Setting up multiple sites?** Read [System Architecture](docs/ARCHITECTURE.md) → Distributed Architecture section
- **Need to program a message?** Check [Message Tables](docs/TABLES.md) for vocabulary, then [Script Reference](docs/REFERENCE.md) for `msgwriter.sh`
- **Troubleshooting?** See [Practical Operations](docs/OPERATIONS.md) → Quick Troubleshooting
- **Upgrading?** See [System Maintenance](docs/MAINTENANCE.md)
