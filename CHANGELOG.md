# Changelog

All notable changes to `app_rpt__ultra` are documented here.

---

## [2.0.7] - 2026-04-01

### Fixed
- **`speaktext.sh`: Audio playback race condition** — `rpt localplay` is asynchronous and returns in ~55ms; the previous EXIT trap (`trap 'rm -f "${speakfile}.ulaw"' EXIT`) deleted the temp file before Asterisk could play it, resulting in silence. The temp file path is now a stable, per-node location (`/opt/app_rpt/lib/speakfile_${MYNODE}.ulaw`) and the EXIT trap has been removed.
- **`weatherkeeper.sh`: NOAA SWPC space weather fetch failure** — `SWPC_OUTPUT` was set to `/tmp/noaa-space-weather.json`. The Linux kernel's `fs.protected_regular` security feature prevents even root from overwriting files in world-writable sticky directories (e.g. `/tmp`) owned by another user. Once the `asterisk` cron created the file, all subsequent writes failed silently with `curl: (23) Permission denied`. Path moved to `/opt/app_rpt/lib/noaa-space-weather.json`.
- **`weatherkeeper.sh`: `jq` dependency not enforced at install time** — `jq` was listed as a dependency but not always present, causing `weatherkeeper.sh` to fail on every run with no weather data updates. The installer now ensures `jq` is available.
- **Allison Smith voice used for app_rpt telemetry instead of TMS5220** — ASL3 resolves `app_rpt` built-in sounds (link connect/disconnect, call proceeding, etc.) from `astdatadir/sounds/en/` which is `/usr/share/asterisk/sounds/en/` — the Allison Smith package location. Both `/usr/share/asterisk/sounds/en` and `/var/lib/asterisk/sounds/en` are now replaced with symlinks to `/opt/app_rpt/sounds` so all telemetry uses TMS5220 voices. A TMS5220 `alllinksrestored.ulaw` has been added to complete the `rpt/` sound set.
- **`msgwriter.sh`: Temp files vulnerable to `fs.protected_regular`** — Fixed paths `/tmp/cwmsg` and `/tmp/voicemsg` moved to `/opt/app_rpt/lib/cwmsg_${MYNODE}` and `/opt/app_rpt/lib/voicemsg_${MYNODE}` (per-node, outside sticky `/tmp`).
- **`kerchunkd.sh`: TOCTOU race in PID file check** — Replaced check-then-write PID file pattern with `flock -n` on a lock file for atomic single-instance enforcement.
- **`configkeeper.sh`: `--delete` on single-file rsync calls** — `rsync --delete` is only meaningful for directory syncs; removed from all five single-file `rsync -az` calls (config.ini, rpt.conf, manager.conf, extensions.conf, allmon3.ini).
- **`repair.sh`: `eval` used for fix command execution** — Replaced `eval "$fix_command"` with `bash -c "$fix_command"` at both call sites in `ask_repair()`.
- **`weatheralert.sh`: Flood messages announced as "heavy rain"** — Flash flood, flood, coastal flood, and lakeshore flood warnings/watches were built from `heavy.ulaw + rain.ulaw`. Changed to `high.ulaw + watt.ulaw + suffix_er.ulaw + warning/watch.ulaw` ("high water warning/watch") to match the correct TMS5220 sound set and more accurately describe the hazard.
- **`upgrade.sh`: sed substitution vulnerable to special characters in user values** — API keys, hostnames, and other user-supplied values containing `/`, `&`, or `\` would corrupt sed expressions. Added `escape_sed_replacement()` helper; all ten config sed substitutions now escape their values before substitution.
- **`kerchunkd.sh`: Daemon exits on transient loop iteration errors** — Extracted loop body to `_loop_iteration()` function; `main_loop()` calls it with `|| log_error …` so individual iteration failures are logged and recovered from without killing the daemon.
- **`install.sh`: Temp file leaked on crontab install failure** — `mktemp` temp file is now explicitly cleaned up if `crontab -u` fails.
- **`configkeeper.sh`: `set -euo pipefail` after `source common.sh`** — Moved `set -euo pipefail` to before the `source` line so errors during common.sh loading are caught.

### Changed
- **Log directory moved from `/var/log/` to `/opt/app_rpt/log/`** — All app_rpt logs (`app_rpt.log`, `state_history.log`, `kerchunk_stats.log`) are now written under `/opt/app_rpt/log/`, keeping all application data self-contained. The `upgrade.sh` migration step automatically moves existing logs from the old location on upgrade. Affected files: `common.sh`, `statekeeper.sh`, `kerchunkd.sh`, `kerchunkd.service`, `configkeeper.sh`, `weatheralert.sh`, `install.sh`, `upgrade.sh`, `repair.sh`.
- **`AUTOUPGRADE` now defaults to `1`** — Child node configs stored on the hub (`/opt/app_rpt/backups/<node>/config.ini`) now ship with `AUTOUPGRADE=1` so distributed deployments propagate upgrades automatically without manual intervention per-node.

### Infrastructure
- `upgrade.sh` now creates `/opt/app_rpt/log/` and migrates logs from `/var/log/` during the upgrade process.
- `install.sh` now creates `/opt/app_rpt/log/` with correct ownership (`asterisk:asterisk`, mode `775`) during fresh installs.
- `install.sh` and `upgrade.sh` now correctly replace `/usr/share/asterisk/sounds/en` and `/var/lib/asterisk/sounds/en` with symlinks to `/opt/app_rpt/sounds`, preserving the Allison Smith backup at `en.allison_backup`.

---

## [2.0.6] - 2026-01-25

### Added
- `common.sh` shared library for configuration loading, validation, and logging across all scripts
- `weatheralert.sh`: Space weather monitoring via NOAA SWPC (geomagnetic storms G1–G5, solar radiation storms S1–S5, radio blackouts R1–R5)
- `weatherkeeper.sh`: UV index warning audio generation (high UV ≥8, extreme UV ≥11)
- `kerchunkd.sh`: Kerchunk detection daemon with passive (statistics) and active (audio deterrence) modes
- `kerchunkd.service`: systemd unit for continuous kerchunk monitoring
- Hub/child architecture with `configkeeper.sh` auto-upgrade support

### Changed
- Security hardening: temp files use unique PID-based names to prevent symlink attacks
- All scripts updated to use `set -euo pipefail` and shared `common.sh` validation

### Fixed
- Weather data parsing rewritten using `jq` for robust JSON handling
- Wind direction audio correctly maps all 8 cardinal/intercardinal directions

---

## [2.0.5] - 2026-01-06

### Added
- Message slot reorganization: weather and space weather grouped into slots 60–69
- AllMon3 integration documentation

### Changed
- `idkeeper.sh`: Supports up to 3 rotating initial IDs and 5 pending IDs
- `tailkeeper.sh`: Supports temperature and time-of-day in tail message rotation
- Sound file structure reorganized under `_male/`, `_female/`, `_sndfx/` subdirectories

---

## [2.0.4] and earlier

Initial releases establishing the core framework: state management, rotating IDs, tail messages, weather alerting via NOAA NWS, weather conditions via Weather Underground, and full `app_rpt` integration without code modification.
