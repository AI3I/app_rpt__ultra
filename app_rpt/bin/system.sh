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

case "$1" in
reboot) # Reboot System
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/stop_and_start_system"
    sleep 5
    systemctl stop asterisk
    sleep 3
    reboot
    exit 0
    ;;
halt) # Halt System
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/stop_system"
    sleep 10
    systemctl stop asterisk
    sleep 3
    poweroff
    exit 0
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.5
