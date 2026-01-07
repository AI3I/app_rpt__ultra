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

#    USAGE:  Accept single digit commands from CLI or DTMF with
#    prepended 0 or otherwise proceed with double digits as entered

if [[ -z "${2:-}" ]]; then
    die_with_error "No command argument provided"
fi

if [[ "$2" =~ ^0 ]]; then
    myvar="${2:1}"  # Remove leading 0
else
    myvar="$2"
fi

case "$1" in
cop) # Control Operator Commands
    asterisk -rx "rpt cmd $MYNODE cop $myvar"
    exit 0
    ;;
ilink) # Internet Linking Commands
    asterisk -rx "rpt cmd $MYNODE ilink $myvar"
    exit 0
    ;;
remote) # Remote Base Commands
    asterisk -rx "rpt cmd $MYNODE remote $myvar"
    exit 0
    ;;
status) # Status Commands
    asterisk -rx "rpt cmd $MYNODE status $myvar"
    exit 0
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.2
