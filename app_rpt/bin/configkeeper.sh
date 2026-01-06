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

# Update sound files
sudo rsync -azr --delete "${FETCHPOINT}:${SNDNODES}/" "${SNDNODES}"
sudo rsync -azr --delete "${FETCHPOINT}:${SNDRPT}/" "${SNDRPT}"
sudo rsync -azr --delete "${FETCHPOINT}:${BACKUPDIR}/${MYNODE}/sounds/ids/" "${SNDID}"

# Reload configuration changes for Asterisk
sleep 5
sudo asterisk -rx "module reload"

# Reload configuration changes for allmon3
sudo systemctl reload allmon3

###VERSION=2.0.1
