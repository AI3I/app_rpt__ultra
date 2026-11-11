#!/usr/bin/env bash

#
#    app_rpt__ultra :: the ultimate controller experience for app_rpt
#    Copyright (C) 2025   John D. Lewis (AI3I)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

set -euo pipefail
source "%%BASEDIR%%/bin/common.sh"

# Runs hourly from the rpt.conf scheduler (macro 9920 -> function C9920) on
# every node.  Only child nodes (FETCHLOCAL=1) pull from a hub; on a hub this
# would copy its own backup config.ini over the live one.
if [[ "${FETCHLOCAL:-0}" != "1" ]]; then
    exit 0
fi

# Every hub connection runs as root (sudo) so it uses root's keys, never prompts,
# and gives up instead of hanging cron when the hub is unreachable.
ssh_cmd="ssh -o BatchMode=yes -o ConnectTimeout=15"
failures=0

# Destinations are resolved to real paths first: /opt/app_rpt/sounds is a
# symlink (owned by asterisk) to sounds/rp, and rsync running as root refuses
# to write through a symlink owned by another user.

# Pull one file from the hub.  A failure is logged and counted, and the
# remaining steps still run.
pull_file() {
    local src="$1" dest
    dest=$(readlink -f "$2" || echo "$2")
    if ! sudo rsync -az -e "$ssh_cmd" "${FETCHPOINT}:${src}" "$dest"; then
        log_error "Failed to sync ${src} from ${FETCHPOINT}"
        failures=$((failures + 1))
    fi
}

# Config files are staged here and applied only when the hub copy has changed
# since it was last applied.  statekeeper.sh edits rpt.conf and config.ini on
# every state change (daytime, nighttime, net, ...); re-applying an unchanged
# hub copy every hour would silently undo those changes.  To force a re-apply,
# delete ${BASEDIR}/lib/hubsync/*.applied.
STAGE="${BASEDIR}/lib/hubsync"
applied=0
allmon_applied=0

# Checksum of a file's settings only: comment (# or ;) and blank lines are
# ignored, so a comment edit or an old version marker never triggers a re-apply.
settings_sum() {
    # awk (not grep -v) so a file with no setting lines still returns success
    sudo awk '!/^[[:space:]]*([#;]|$)/' "$1" | sha256sum | cut -d' ' -f1
}

pull_config() {
    local src="$1" dest name staged sum last
    dest=$(readlink -f "$2" || echo "$2")
    name=$(basename "$src")
    staged="$STAGE/$name"
    # Records written before 2.0.10 hold a whole-file checksum.  If the record
    # still matches the copy staged last time, convert it to a settings checksum
    # so changing the method doesn't cause a one-time re-apply.
    if sudo test -f "$staged" && sudo test -f "$staged.applied"; then
        last=$(sudo cat "$staged.applied")
        if [[ "$last" == "$(sudo sha256sum "$staged" | cut -d' ' -f1)" ]]; then
            settings_sum "$staged" | sudo tee "$staged.applied" >/dev/null
        fi
    fi
    # -c compares contents: a same-size edit within the same second as the last
    # sync must still be fetched
    if ! sudo rsync -ac -e "$ssh_cmd" "${FETCHPOINT}:${src}" "$staged"; then
        log_error "Failed to sync ${src} from ${FETCHPOINT}"
        failures=$((failures + 1))
        return 0
    fi
    sum=$(settings_sum "$staged")
    last=$(sudo cat "$staged.applied" 2>/dev/null || true)
    if [[ "$sum" == "$last" ]]; then
        return 0
    fi
    if sudo rsync -ac "$staged" "$dest"; then
        echo "$sum" | sudo tee "$staged.applied" >/dev/null
        log "Applied updated ${name} from ${FETCHPOINT}"
        applied=$((applied + 1))
        [[ "$name" == "allmon3.ini" ]] && allmon_applied=1
    else
        log_error "Failed to install ${name} from ${FETCHPOINT}"
        failures=$((failures + 1))
    fi
    return 0
}

# Mirror one directory from the hub (removes local files the hub no longer has).
pull_dir() {
    local src="$1" dest
    dest=$(readlink -f "$2" || echo "$2")
    if ! sudo rsync -azr --delete -e "$ssh_cmd" "${FETCHPOINT}:${src}/" "${dest}/"; then
        log_error "Failed to sync ${src}/ from ${FETCHPOINT}"
        failures=$((failures + 1))
    fi
}

# Auto-upgrade detection for child nodes
# Only runs on child nodes (FETCHLOCAL=1) when AUTOUPGRADE=1.  The hub stages a
# full copy of the release in ${BASEDIR}/src (upgrade.sh/install.sh do this);
# upgrade.sh needs that tree, not just the util/ scripts.
if [[ "${FETCHLOCAL:-0}" == "1" ]] && [[ "${AUTOUPGRADE:-0}" == "1" ]]; then
    hub_version=$(sudo $ssh_cmd "${FETCHPOINT}" "cat ${BASEDIR}/VERSION" 2>/dev/null || echo "unknown")
    local_version=$(cat "${BASEDIR}/VERSION" 2>/dev/null || echo "unknown")

    if [[ "$hub_version" == "unknown" ]]; then
        log_error "Could not read ${BASEDIR}/VERSION on ${FETCHPOINT}; auto-upgrade check skipped"
    elif [[ "$local_version" != "unknown" ]] && [[ "$hub_version" != "$local_version" ]]; then
        log "Hub version ($hub_version) differs from local ($local_version); auto-upgrading"
        if ! sudo rsync -azr --delete -e "$ssh_cmd" "${FETCHPOINT}:${BASEDIR}/src/" "${BASEDIR}/src/"; then
            log_error "Could not fetch ${BASEDIR}/src from ${FETCHPOINT} (run upgrade.sh on the hub to stage it); auto-upgrade skipped"
            failures=$((failures + 1))
        else
            rc=0
            sudo bash "${BASEDIR}/src/upgrade.sh" --force --auto-yes >>"$LOG_FILE" 2>&1 || rc=$?
            if [[ $rc -eq 0 ]]; then
                log "Auto-upgrade completed (v$local_version -> v$hub_version)"
            else
                log_error "Auto-upgrade v$local_version -> v$hub_version failed (upgrade.sh exit $rc); continuing with config sync"
                failures=$((failures + 1))
            fi
        fi
    fi
fi

# Configuration files: applied only when the hub copy has changed (see above)
sudo mkdir -p "$STAGE"
pull_config "${BACKUPDIR}/${MYNODE}/config.ini" "${BASEDIR}/config.ini"
pull_config "${BACKUPDIR}/${MYNODE}/rpt.conf" /etc/asterisk/rpt.conf
pull_config "${BACKUPDIR}/${MYNODE}/manager.conf" /etc/asterisk/manager.conf
pull_config "${BACKUPDIR}/${MYNODE}/extensions.conf" /etc/asterisk/custom/extensions.conf
if [[ -d /etc/allmon3 ]]; then
    pull_config "${BACKUPDIR}/${MYNODE}/allmon3.ini" /etc/allmon3/allmon3.ini
fi

# Update scripts from bin directory
pull_dir "${BINDIR}" "${BINDIR}"

# Update utility scripts (install, upgrade, repair, uninstall, migrate-lang)
pull_dir "${UTILDIR}" "${UTILDIR}"

# Update sound files
# SNDNODES normally lives inside SNDRPT (rpt/nodenames), which the SNDRPT
# mirror already covers; syncing it separately failed on hubs without one.
if [[ "${SNDNODES}" != "${SNDRPT}"/* ]]; then
    pull_dir "${SNDNODES}" "${SNDNODES}"
fi
pull_dir "${SNDRPT}" "${SNDRPT}"
# Recorded IDs are copied, never mirrored: an empty or missing ids/ in the hub's
# backup must not delete the IDs this node transmits.
pull_file "${BACKUPDIR}/${MYNODE}/sounds/ids/" "${SNDID}/"

# Reload only when a config file was applied (even if other steps failed, so
# the running config matches what is on disk); an hourly reload with nothing
# new would only disturb a node that is in service.
if [[ $applied -gt 0 ]]; then
    sleep 5
    sudo asterisk -rx "module reload" || log_error "Asterisk module reload failed"
fi
if [[ $allmon_applied -eq 1 ]]; then
    sudo systemctl reload allmon3 || log_error "allmon3 reload failed"
fi

if [[ $failures -gt 0 ]]; then
    log_error "Config sync from ${FETCHPOINT} finished with $failures failed step(s)"
    exit 1
fi
log "Config sync from ${FETCHPOINT} complete"
