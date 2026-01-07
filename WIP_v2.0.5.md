# v2.0.5 Work In Progress

## Current Status
**Branch:** main
**Last Commit:** v2.0.5 WIP: Slot 00 CW ID, slot reorganization, security improvements
**Status:** Changes committed but NOT tagged or released yet

## Completed for v2.0.5

### ✅ Slot 00 CW ID Feature
- **File:** `app_rpt/bin/msgreader.sh`
- **What:** Slot 00 now triggers CW (morse code) ID using `asterisk -rx "rpt playback $MYNODE |m"`
- **How:** Special case in msgreader.sh before normal slot lookup
- **Uses:** Plays CW ID from rpt.conf `idtalkover` settings (callsign, pitch, speed)
- **Testing:** Ready to test on node504381

### ✅ Message Slot Reorganization
- **File:** `app_rpt/lib/messagetable.txt`
- **Changes:**
  - Slot 00: `rpt/cw_id` (NEW - CW ID trigger)
  - Slots 51-59: Now `custom/available_XX` (freed for user messages)
  - Slot 60: `weather/wx_severe_alert` (moved from 52)
  - Slot 61: `weather/wx_alert` (moved from 51)
  - Slots 62-69: Space weather (reserved: geomagnetic, radio, solar storms)
  - Slot 79: `wx/uv_warning` (NEW - UV index warning)
  - Slots 96-99: Net messages (moved from 53-55, added 99 for 15-min warning)

### ✅ Security Improvements
- **File:** `.gitignore`
  - Excludes: `app_rpt/config.ini`, `asterisk/rpt.conf`, `asterisk/extensions_custom.conf`
  - Prevents DTMF codes, API keys, node numbers from being committed
- **Files renamed:**
  - `app_rpt/config.ini` → `app_rpt/config.ini.example`
  - Deleted `asterisk/rpt.conf` and `asterisk/extensions_custom.conf` from repo
- **Note:** User emphasized keeping DTMF codes private

### ✅ Documentation
- **SLOTS.md:** Complete reference of all 100 message slots
- **MIGRATION_v2.0.5.md:** Step-by-step upgrade guide from v2.0.4
- Both ready for users

### ✅ Dependencies Added
- **Files:** `install.sh`, `upgrade.sh`
- **Added:** `fzf`, `dialog` installation
- **Reason:** Reserved for future features (currently unused)

## What's NOT Done Yet

### ❌ msgbuilder.sh - SCRAPPED
- **Attempts:** 7+ different UI approaches (dialog, curses, Python TUI, fzf)
- **Outcome:** All rejected as too complicated
- **Decision:** Removed entirely from repo and node504381
- **Status:** Feature postponed or abandoned
- **User feedback:** "Let's just scrap this"

### ✅ Space Weather Monitoring (ADDED)
- **File:** `app_rpt/bin/weatherkeeper.sh`
- **What:** Monitors NOAA SWPC for geomagnetic storms, radio blackouts, solar radiation
- **API:** https://services.swpc.noaa.gov/products/noaa-scales.json
- **Audio Messages:**
  - Geomagnetic (slots 62-64): "light/moderate/severe geo storm alert/warning" (uses G+O for "geo")
  - Radio (slots 65-67): "light/moderate/severe radio condition alert/warning"
  - Solar (slots 68-69): "low/high S storm alert/warning"
- **Status:** Committed, ready to test

### 🔮 Future Features for v2.0.5
User said: "we'll add more to this version later"

**Potential additions:**
1. ✅ Space weather alert automation (slots 62-69) - DONE
2. ✅ UV index warning automation (slot 79) - DONE (already in weatherkeeper.sh)
3. Net countdown messages automation (slots 96-99) - TBD
4. Other features TBD

## Files Changed (Committed)
```
new file:   .gitignore
new file:   MIGRATION_v2.0.5.md
new file:   SLOTS.md
modified:   app_rpt/bin/msgreader.sh
modified:   app_rpt/bin/weatherkeeper.sh
renamed:    app_rpt/config.ini -> app_rpt/config.ini.example
modified:   app_rpt/lib/messagetable.txt
deleted:    asterisk/extensions_custom.conf
deleted:    asterisk/rpt.conf
modified:   install.sh
modified:   upgrade.sh
```

## Untracked Files
- `CONFIGURATION.md` - Not added yet
- `asterisk/` directory - Likely local configs, should stay untracked

## Testing Status
- **node504381:** Has common.sh fixed (%%BASEDIR%% replaced)
- **Slot 00:** NOT tested yet
- **Slot reorganization:** NOT tested yet
- **Security changes:** Applied

## Important Notes

### User Preferences & Lessons Learned
1. **Keep it simple:** User rejected multiple complex UIs, wanted "single pane" solutions
2. **No over-engineering:** Avoid spreadsheets, TUIs, multi-step workflows
3. **DTMF security:** Never commit DTMF codes or node-specific configs
4. **Testing on node504381:** User prefers testing on actual hardware, not local mock environments

### Technical Decisions
1. **Slot 00 implementation:** Uses `rpt playback |m` command (pipes morse code)
2. **Message slots 51-59:** Now available for custom user messages
3. **Weather organization:** All weather/space in 60-79 range
4. **Net messages:** High slots 96-99 for sequential countdown

## Next Steps (When Resuming)

1. **Test Slot 00:**
   ```bash
   ssh ai3i@repeater.ai3i.net
   sudo su -
   ssh node504381
   /opt/app_rpt/bin/msgreader.sh 00
   ```

2. **Decide on additional v2.0.5 features:**
   - Space weather automation?
   - UV warning automation?
   - Net countdown automation?
   - Something else?

3. **When ready to release:**
   - Update VERSION files to 2.0.5
   - Create git tag: `git tag -a v2.0.5 -m "..."`
   - Push: `git push && git push --tags`
   - Create GitHub release

## Quick Reference

**Git status:** Changes committed, not tagged/released
**Version:** 2.0.5 WIP
**Ready to test:** Slot 00 CW ID, slot reorganization
**Scrapped:** msgbuilder.sh (too complex, removed)
**Next:** Add more features or test/release current changes
