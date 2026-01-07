# Migration Guide: v2.0.4 → v2.0.5

## Message Slot Reorganization

Version 2.0.5 reorganizes message slots for better organization and to make room for space weather alerts.

### What's Changing

| Old Slot | Old Path | New Slot | New Path | Action Required |
|----------|----------|----------|----------|-----------------|
| 51 | `tails/weather_alert` | 61 | `weather/wx_alert` | Update config.ini |
| 52 | `tails/severe_weather_alert` | 60 | `weather/wx_severe_alert` | Update config.ini |
| 53 | `rpt/net_in_one_minute` | 96 | `rpt/net_in_one_minute` | Update AllMon3 |
| 54 | `rpt/net_in_five_minutes` | 97 | `rpt/net_in_five_minutes` | Update AllMon3 |
| 55 | `rpt/net_in_ten_minutes` | 98 | `rpt/net_in_ten_minutes` | Update AllMon3 |
| - | *(new)* | 79 | `wx/uv_warning` | Auto-generated |
| - | *(new)* | 99 | `rpt/net_in_fifteen_minutes` | Optional |

### Benefits

✅ **Freed Slots 51-59** - Now available for your custom messages
✅ **Weather Block 60-69** - All weather/space weather organized together
✅ **Net Messages 96-99** - Sequential high slots for net operations
✅ **Space Weather Ready** - Slots 62-69 reserved for future space weather alerts

## Step-by-Step Migration

### 1. Update config.ini

Edit `/opt/app_rpt/config.ini`:

```ini
# OLD (v2.0.4):
SVWXALERT=tails/severe_weather_alert
RTWXALERT=tails/weather_alert

# NEW (v2.0.5):
SVWXALERT=weather/wx_severe_alert
RTWXALERT=weather/wx_alert
```

### 2. Move Message Files (if customized)

If you customized the weather alert tail messages, move them:

```bash
# Create weather directory if it doesn't exist
sudo mkdir -p /opt/app_rpt/sounds/weather

# Move files to new locations
sudo mv /opt/app_rpt/sounds/tails/severe_weather_alert.ulaw \
        /opt/app_rpt/sounds/weather/wx_severe_alert.ulaw

sudo mv /opt/app_rpt/sounds/tails/weather_alert.ulaw \
        /opt/app_rpt/sounds/weather/wx_alert.ulaw

# Set permissions
sudo chown asterisk:asterisk /opt/app_rpt/sounds/weather/*.ulaw
```

**Note:** If you didn't customize these files, they'll be auto-created in the new locations.

### 3. Update AllMon3 (if installed)

If you use AllMon3, edit `/etc/allmon3/web.ini` to update slot references:

**Slot Changes:**
- Severe Weather Alert: slot 52 → slot 60
- Weather Alert: slot 51 → slot 61
- Net in 1 minute: slot 53 → slot 96
- Net in 5 minutes: slot 54 → slot 97
- Net in 10 minutes: slot 55 → slot 98
- Net in 15 minutes: (new) → slot 99
- UV index: (new) → slot 79
- Space weather: (reserved) → slots 62-69

Update your DTMF command definitions to reference the new slot numbers.

Then restart AllMon3:

```bash
sudo systemctl restart allmon3
```

### 4. Test the Migration

Verify everything works:

```bash
# Test weather alert playback (old DTMF won't work anymore)
asterisk -rx "rpt localplay YOURNODE weather/wx_alert"
asterisk -rx "rpt localplay YOURNODE weather/wx_severe_alert"

# Test net messages (new slots)
asterisk -rx "rpt localplay YOURNODE rpt/net_in_one_minute"
asterisk -rx "rpt localplay YOURNODE rpt/net_in_fifteen_minutes"

# Test UV warning (auto-generated)
asterisk -rx "rpt localplay YOURNODE wx/uv_warning"
```

### 5. Update Custom Messages (if any)

If you had custom messages in slots 51-55, rebuild them in new locations:

```bash
# Use msgbuilder.sh for easy rebuilding
sudo /opt/app_rpt/bin/msgbuilder.sh

# Or use msgwriter.sh with new slot numbers
```

## Rollback Procedure

If you need to rollback to v2.0.4:

```bash
# 1. Restore old config.ini settings
sudo sed -i 's|SVWXALERT=weather/wx_severe_alert|SVWXALERT=tails/severe_weather_alert|' /opt/app_rpt/config.ini
sudo sed -i 's|RTWXALERT=weather/wx_alert|RTWXALERT=tails/weather_alert|' /opt/app_rpt/config.ini

# 2. Move files back
sudo mv /opt/app_rpt/sounds/weather/wx_severe_alert.ulaw \
        /opt/app_rpt/sounds/tails/severe_weather_alert.ulaw
sudo mv /opt/app_rpt/sounds/weather/wx_alert.ulaw \
        /opt/app_rpt/sounds/tails/weather_alert.ulaw

# 3. Restore old messagetable.txt from v2.0.4 backup

# 4. Revert AllMon3 changes in /etc/allmon3/web.ini

# 5. Restart Asterisk
sudo asterisk -rx "module reload"
```

## Frequently Asked Questions

### Q: Will my existing custom messages be lost?

**A:** No! The upgrade only changes the slot mappings. Any custom messages you created will remain, but if they were in slots 51-55, you'll need to access them via the new slot numbers (they're now in slots 60-61 for weather, or 96-98 for net messages).

### Q: Do I need to rebuild my ID and tail messages?

**A:** No! Slots 01-19 (IDs and tail messages) haven't changed. Your existing messages will continue to work.

### Q: What if I don't use AllMon3?

**A:** You only need to update `config.ini`. The AllMon3 steps can be skipped.

### Q: Will weather alerts still work automatically?

**A:** Yes! The weatheralert.sh script will automatically use the new paths from config.ini. Custom TMS5220 messages for specific weather events continue to work.

### Q: Will my DTMF commands still work after upgrading?

**A:** You'll need to update your AllMon3 configuration and any custom DTMF definitions in rpt.conf to reference the new slot numbers (see migration guide above).

### Q: What are slots 62-69 for?

**A:** These are reserved for future space weather alerts (NOAA SWPC geomagnetic storms, radio blackouts, and solar radiation). They'll be implemented in a future release.

### Q: Can I use the newly freed slots 51-59?

**A:** Yes! These are now available for any custom messages you want to create. Use `msgbuilder.sh` to create custom messages in these slots.

## Need Help?

If you encounter issues during migration:

1. Check `/var/log/asterisk/messages.log` for errors
2. Verify file permissions: `ls -la /opt/app_rpt/sounds/weather/`
3. Test message playback manually with `asterisk -rx "rpt localplay"`
4. Review [CONFIGURATION.md](CONFIGURATION.md) for detailed setup guide

## Summary

**Required Changes:**
- ✅ Update `config.ini` weather alert paths
- ✅ Move weather alert .ulaw files (if customized)
- ✅ Update AllMon3 DTMF codes (if using AllMon3)

**Optional:**
- Rebuild any custom messages that were in old slots 51-55
- Add "net in 15 minutes" message to slot 99
- Prepare for space weather alerts (coming soon)

**No Changes Needed:**
- ID messages (01-10)
- Tail messages (11-19)
- Weather telemetry (70-78) - auto-generated
- Repeaterisms (81-95)

---

**Estimated Migration Time:** 5-10 minutes

**Difficulty:** Easy (just config file edits)

**Rollback:** Simple (restore old config.ini and file locations)
