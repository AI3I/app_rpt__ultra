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

# Purge log files after retention period
sudo find /var/log/asterisk/ -not -empty -type f -mtime +"${RETENTION}" -exec rm {} \;
# Purge recordings after retention period
sudo find /opt/asterisk/ -not -empty -type f -mtime +"${RETENTION}" -exec rm {} \;

# Upload recordings to master host
if [[ "$FETCHLOCAL" == "1" ]]; then
    # Proceed if not a hub node
    rsync -azrv --delete "${RECORDDIR}/${MYNODE}/" "${FETCHPOINT}:${RECORDDIR}/${MYNODE}/"
elif [[ "$FETCHLOCAL" == "0" ]]; then
    # Ignore if operating as a hub
    exit 0
else
    exit 1
fi

###VERSION=2.0.4
