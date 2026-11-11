# Changelog

All notable changes to `app_rpt__ultra` are documented here.

---

## [Unreleased]

### Fixed
- **`upgrade.sh`, `install.sh`, `repair.sh`: `rm -rf` of a pre-rp `sounds/` directory** — Replacing a real `/opt/app_rpt/sounds` with a symlink deleted recorded IDs, tails and custom messages. On nodes where `/usr/share/asterisk/sounds` is itself a symlink to `/opt/app_rpt/sounds`, `sounds/rp` lived inside the old directory and was deleted as well. All three now hand the layout change to `migrate-lang.sh`, which never deletes anything.
- **`migrate-lang.sh`: unsafe on symlinked layouts** — Replaces parent symlinks into the old directory with real directories, removes `en` symlinks by resolved path (trailing-slash or relative targets were previously skipped), refuses if `sounds/rp` would resolve inside the old directory, copies `ids/ tails/ custom/ rpt/ recordings/` plus `voice_id`/`tail_message`, and moves the old directory to `backups/sounds_premigration_<timestamp>/` instead of deleting it. Safe to re-run; installed into `util/`.
- **`configkeeper.sh`: child auto-upgrade always failed and stopped all syncing** — It ran `util/upgrade.sh`, which can't find the release tree from `util/`; under `set -e` the failure ended the script before any config, script or sound sync. Hubs now stage the release in `${BASEDIR}/src` (`upgrade.sh`, `install.sh`) and children run `src/upgrade.sh`; a failure is logged and the sync continues.
- **`configkeeper.sh`: one failed `rsync` skipped every later step and the Asterisk reload** — Each sync is guarded and counted; files that did sync are still reloaded, and the script exits 1 if anything failed.
- **`configkeeper.sh`: hub version check used the asterisk user's SSH keys** — All hub connections now run as root (matching the syncs) with `BatchMode`/`ConnectTimeout`, so cron can't hang on a prompt. Recorded IDs are copied from the hub rather than mirrored with `--delete`.
- **`msgwriter.sh`: a typo could replace an ID with silence** — Unknown vocabulary codes were skipped and `xargs cat` with no input truncated the slot to 0 bytes. Every code is resolved before writing, the slot is built under a temporary name and moved into place, input without the `D` delimiter is rejected, and an empty CW ID is never written.
- **`ctwriter.sh`: CT slots 08 and 09 could not be programmed** — Bash parsed them as invalid octal. Type A (vocabulary) tones also never copied their sound (path doubled) while `rpt.conf` was still repointed, silencing the tone.
- **`weatherkeeper.sh`: decimals read as clock words** — Fractions were played with the two-digit `00`–`09` files ("o'clock", "oh four"); each fractional digit is now spoken individually. Whole numbers without a decimal point no longer repeat as the fraction ("thirty point three zero").
- **`configkeeper.sh` was never run** — `rpt.conf.example` now schedules it hourly (function `C5010`, macro `5010`). It exits immediately on hubs (`FETCHLOCAL` other than `1`), where it would have copied the hub's backup `config.ini` over its live one.
- **`datadumper.sh`: recordings pushed to the hub with `--delete`** — An empty or reimaged child could wipe the hub's copy of its recordings; the hub's own retention purge now handles cleanup.
- **`timekeeper.sh`: time clip written in place** — A failed build left a truncated `current_time.ulaw`; it is now built under a temporary name and moved into place.
- **`msgreader.sh`: loose slot match** — `"1"` matched slot `01`; slots must be two digits and match exactly. `restart.sh`/`msgreader.sh` no longer trip `set -u` when run without an argument.
- **`repair.sh`: `language=rp` never added to `chan_dahdi.conf`** — The `sed || sed` fallback never ran because `sed` succeeds on no match.
- **`restart.sh`: `eth0`/`wlan0` rejected** — Deployed `rpt.conf` files call `restart.sh eth0` and `restart.sh wlan0`; only `lan`/`wlan` were accepted, so those restarts played `program_error`. Both names now work.
- **`kerchunkd.service`: endless restart loop** — A daemon failing at startup was restarted every 10 seconds forever (188,000 restarts and ~17,000 log lines a day on one node). It now stops after 5 failures in 10 minutes, and `upgrade.sh` restarts it whenever the service is enabled so the fixed script is picked up.
- **No log rotation** — `/opt/app_rpt/log/*.log` grew without limit; `install.sh`/`upgrade.sh` now install `/etc/logrotate.d/app_rpt__ultra` (weekly, 8 kept, compressed).
- **`configkeeper.sh`: sound sync failed on migrated nodes** — rsync 3.5 refuses, as root, to write through the asterisk-owned `/opt/app_rpt/sounds` symlink; destinations are now resolved to real paths first. `migrate-lang.sh` no longer reports a clean `sounds/en/` when the package reinstall failed.
- **`tailkeeper.sh`: unrecorded tail slots played as silence** — The tail link pointed at `tail_message_N` whether or not it had been recorded. Only existing recordings are used now (time/temperature keep their equal share), a missing severe-weather recording falls back to the normal tail, and with nothing available the link is removed and logged once.
- **`configkeeper.sh`: hourly error on hubs without `rpt/nodenames`** — The separate `nodenames` sync is skipped when it lives inside `rpt/`, which is already mirrored.
- **`upgrade.sh`: hubs handed children old-format configs** — Children pull `config.ini` from the hub's `backups/<node>/` copy every hour, but `upgrade.sh` only migrated the node's own config, so a freshly upgraded child got an old-format config back (missing settings crashed `kerchunkd`). Upgrading a hub now migrates every `backups/<node>/config.ini` with the same carry-over rules, saving originals in the upgrade backup; copies that don't load cleanly are left untouched with a warning. Deliberately empty values now also survive over template placeholders.
- **`upgrade.sh`: settings reset on every upgrade** — `migrate_config` now carries over every non-empty, non-path setting from the existing `config.ini` (previously `AUTOUPGRADE`, ID/tail rotation, `KERCHUNK_*`, CT names and timers were reset to defaults).

---

## [2.0.8] - 2026-04-02

### Fixed
- **`weatheralert.sh`: Alert audio temp file vulnerable to `fs.protected_regular`** — `/tmp/weather_alert_message.ulaw` failed silently after first run (same root cause as 2.0.7 `weatherkeeper.sh` fix). Moved to stable per-node path `${BASEDIR}/lib/weatheralert_${MYNODE}.ulaw`.
- **`kerchunkd.sh`: PID/lock/state files in `/tmp` vulnerable to `fs.protected_regular`** — `/tmp/kerchunkd.pid`, `/tmp/kerchunkd.lock`, and `/tmp/app_rpt_kerchunk/` moved to `${BASEDIR}/lib/` per-node paths.
- **`statekeeper.sh`: State file in `/tmp` vulnerable to `fs.protected_regular`** — `/tmp/app_rpt_last_state` moved to `${BASEDIR}/lib/last_state_${MYNODE}`.
- **`statekeeper.sh`: sed injection via courtesy tone config values** — CT config values (e.g. `ct/unlinked`) containing `/` corrupted `rpt.conf` sed expressions. All CT variable substitutions now wrapped with `escape_sed_replacement()`.
- **`statekeeper.sh`: `set -euo pipefail` after `source common.sh`** — Moved before `source` so errors during `common.sh` loading are caught (same fix applied to `configkeeper.sh` in 2.0.7).
- **`weatheralert.sh`, `asterisk.sh`, `cmdparser.sh`, `ctkeeper.sh`, `ctwriter.sh`: `set -euo pipefail` after `source common.sh`** — Moved before `source` in all five scripts.
- **`msgwriter.sh`: `xargs cat` splits on whitespace** — Changed to `xargs -d '\n' cat` so sound file paths containing spaces are handled correctly.

### Infrastructure
- `escape_sed_replacement()` moved to `common.sh` so all scripts can use it (previously only available in `upgrade.sh`).

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
