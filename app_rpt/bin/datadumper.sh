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

source "%%BASEDIR%%/bin/common.sh"
set -euo pipefail

# Validate retention period is set
if [[ -z "${RETENTION:-}" ]]; then
    log_error "RETENTION not set in config"
    exit 1
fi

# Purge log files after retention period
if ! sudo find /var/log/asterisk/ -not -empty -type f -mtime +"${RETENTION}" -exec rm {} \; 2>/dev/null; then
    log_error "Failed to purge old log files"
fi

# Purge recordings after retention period.  -mindepth 2: only the per-node
# directories age out; the recordings page (index.html, recordings.json) sits
# at the top of /opt/asterisk and must survive.
if ! sudo find /opt/asterisk/ -mindepth 2 -not -empty -type f -mtime +"${RETENTION}" -exec rm {} \; 2>/dev/null; then
    log_error "Failed to purge old recordings"
fi

# Upload recordings to master host
if [[ "$FETCHLOCAL" == "1" ]]; then
    # Proceed if not a hub node
    if [[ -z "${RECORDDIR:-}" ]] || [[ -z "${FETCHPOINT:-}" ]]; then
        log_error "RECORDDIR or FETCHPOINT not set for rsync"
        exit 1
    fi
    # No --delete: the hub keeps its copy until its own RETENTION purge, so an
    # empty or reimaged child can't wipe the hub's archive of its recordings.
    # sudo: the hub's SSH key and known_hosts entry belong to root (configkeeper.sh
    # syncs the same way); run as the asterisk user, every upload failed host-key
    # verification.
    if ! err=$(sudo rsync -az -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
        "${RECORDDIR}/${MYNODE}/" "${FETCHPOINT}:${RECORDDIR}/${MYNODE}/" 2>&1); then
        log_error "Recordings not uploaded to ${FETCHPOINT}; the hub's archive is missing this node's recent recordings: ${err//$'\n'/ }"
        exit 1
    fi
    log "Recordings uploaded to ${FETCHPOINT}"
elif [[ "$FETCHLOCAL" == "0" ]]; then
    # Ignore if operating as a hub
    exit 0
else
    exit 1
fi
