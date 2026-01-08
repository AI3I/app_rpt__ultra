# Configuration Guide

## System-Specific Configuration Files

**IMPORTANT:** The following files contain node-specific settings and are **NOT** tracked in git:

- `asterisk/rpt.conf` - Asterisk app_rpt configuration
- `asterisk/extensions_custom.conf` - Custom Asterisk dialplan
- `app_rpt/config.ini` - app_rpt__ultra settings

## Using Template Files

Template files (`.example`) are provided as starting points:

### First-Time Setup

```bash
# Copy templates to create your configs
cp asterisk/rpt.conf.example asterisk/rpt.conf
cp asterisk/extensions_custom.conf.example asterisk/extensions_custom.conf
cp app_rpt/config.ini.example app_rpt/config.ini

# Edit each file and customize:
# - Replace %MYNODE% with your node number
# - Replace %MYCALL% with your callsign
# - Configure your network settings
# - Set your API keys
# - Customize DTMF codes
```

### Placeholders in Templates

Templates use the following placeholders:

| Placeholder | Replace With | Example |
|-------------|--------------|---------|
| `%MYNODE%` | Your node number | `504380` |
| `%MYCALL%` | Your callsign | `AI3I` |
| `%WUAPIKEY%` | Weather Underground API key | `your_key_here` |
| `%WUSTATION%` | Weather station ID | `KPASTATE1` |
| `%NWSZONE%` | NWS zone code | `PAZ060` |

## AllMon3 Configuration

AllMon3 is typically installed in `/etc/allmon3/` and is **NOT** part of this repository.

### Message Slot References

If you use AllMon3, update `/etc/allmon3/web.ini` to reference the new slot mappings after upgrading to v2.0.5:

**Slot Organization:**
- Slot 00: CW ID trigger
- Slots 60-61: Weather alerts
- Slots 62-69: Space weather (reserved)
- Slots 70-79: Weather telemetry
- Slots 96-99: Net operations

See [SLOTS.md](SLOTS.md) for complete slot mapping details.

## Message Slot Reorganization (v2.0.5)

### What Changed

**Moved Slots:**
- Slot 51 → 61 (Weather Alert tail message)
- Slot 52 → 60 (Severe Weather Alert tail message)
- Slot 53 → 96 (Net in 1 minute)
- Slot 54 → 97 (Net in 5 minutes)
- Slot 55 → 98 (Net in 10 minutes)

**Added Slots:**
- Slot 79 (UV Index warning - auto-generated)
- Slot 99 (Net in 15 minutes)
- Slots 62-69 (Reserved for space weather)

**Freed Up:**
- Slots 51-59 now available for custom messages!

### Why the Change

1. **Organized Weather Block (60-69)**: All weather and space weather in one logical section
2. **Net Operations at End (96-99)**: Sequential high-number slots for net operations
3. **Freed Slots 51-59**: More slots available for custom use
4. **AllMon3 Friendly**: Logical slot grouping for easier integration

### Updating Your System

After upgrading to v2.0.5:

1. **messagetable.txt** - automatically updated by upgrade
2. **config.ini** - UPDATE these paths:
   ```ini
   # OLD:
   SVWXALERT=tails/severe_weather_alert
   RTWXALERT=tails/weather_alert

   # NEW:
   SVWXALERT=weather/wx_severe_alert
   RTWXALERT=weather/wx_alert
   ```

3. **AllMon3 web.ini** - Update slot references as shown above

4. **Your messages** - If you customized slots 51-55, rebuild them in new locations using msgbuilder.sh

## Security Best Practices

### Never Commit These Files

- ❌ `asterisk/rpt.conf` - Contains your DTMF codes
- ❌ `app_rpt/config.ini` - Contains API keys
- ❌ `/etc/allmon3/web.ini` - Contains node-specific commands
- ❌ Custom message .ulaw files - Your voice IDs

### Safe to Commit

- ✅ `.example` template files (generic)
- ✅ `app_rpt/bin/*.sh` scripts
- ✅ `app_rpt/lib/*.txt` lookup tables (messagetable.txt, vocabulary.txt, etc.)
- ✅ Documentation (README.md, *.md files)

## DTMF Code Organization

When customizing your DTMF codes in `rpt.conf`, organize them logically for easy recall:

### Standard AllStarLink Prefixes
- Single/double digit codes for core functions (disconnect, connect, status)
- Macro prefixes for complex command sequences
- Message playback slots

### Custom Command Organization
- Group related functions together (weather, operations, admin, GPIO)
- Use consistent patterns for similar operations
- Document your codes in a separate private reference file (NOT in git)

## Support

For questions about configuration:
- Check the [README.md](README.md) for feature documentation
- See [SLOTS.md](SLOTS.md) for message slot details
- Review [MSGBUILDER.md](MSGBUILDER.md) for message creation

---

**Remember:** Never share your actual configuration files publicly. They contain sensitive information like API keys, node numbers, and your custom DTMF codes.
