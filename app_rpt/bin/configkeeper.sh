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

# Auto-upgrade detection for child nodes
# Only runs on child nodes (FETCHLOCAL=1) when AUTOUPGRADE=1
if [[ "${FETCHLOCAL:-0}" == "1" ]] && [[ "${AUTOUPGRADE:-0}" == "1" ]]; then
    # Get hub's version
    hub_version=$(ssh "${FETCHPOINT}" "cat %%BASEDIR%%/VERSION 2>/dev/null" || echo "unknown")

    # Get local version
    local_version=$(cat "%%BASEDIR%%/VERSION" 2>/dev/null || echo "unknown")

    # If versions differ, auto-upgrade
    if [[ "$hub_version" != "unknown" ]] && [[ "$local_version" != "unknown" ]] && [[ "$hub_version" != "$local_version" ]]; then
        log "Hub version ($hub_version) differs from local ($local_version)"
        log "Auto-upgrading child node..."

        # Sync util directory first to get latest upgrade.sh
        sudo rsync -azr --delete "${FETCHPOINT}:${UTILDIR}/" "${UTILDIR}" 2>&1 || log_error "Failed to sync util directory"

        # Run upgrade
        if [[ -x "%%BASEDIR%%/util/upgrade.sh" ]]; then
            log "Running upgrade.sh --force --auto-yes"
            sudo "%%BASEDIR%%/util/upgrade.sh" --force --auto-yes >>/var/log/app_rpt.log 2>&1
            if [[ $? -eq 0 ]]; then
                log "Auto-upgrade completed successfully (v$local_version -> v$hub_version)"
            else
                log_error "Auto-upgrade failed, check /var/log/app_rpt.log"
            fi
        else
            log_error "upgrade.sh not found or not executable at %%BASEDIR%%/util/upgrade.sh"
        fi
    fi
fi

# Update local node master configuration file
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/config.ini" "${BASEDIR}/config.ini"
sleep 2

# Replace configuration files with newer version, if necessary
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/rpt.conf" /etc/asterisk/rpt.conf
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/manager.conf" /etc/asterisk/manager.conf
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/extensions.conf" /etc/asterisk/custom/extensions.conf
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/allmon3.ini" /etc/allmon3/allmon3.ini

# Update scripts from bin directory
sudo rsync -azr --delete "${FETCHPOINT}:${BINDIR}/" "${BINDIR}"

# Update utility scripts (install, upgrade, repair, uninstall)
sudo rsync -azr --delete "${FETCHPOINT}:${UTILDIR}/" "${UTILDIR}"

# Update sound files
sudo rsync -azr --delete "${FETCHPOINT}:${SNDNODES}/" "${SNDNODES}"
sudo rsync -azr --delete "${FETCHPOINT}:${SNDRPT}/" "${SNDRPT}"
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/sounds/ids/" "${SNDID}"

# Reload configuration changes for Asterisk
sleep 5
sudo asterisk -rx "module reload"

# Reload configuration changes for allmon3
sudo systemctl reload allmon3

###VERSION=2.0.3
