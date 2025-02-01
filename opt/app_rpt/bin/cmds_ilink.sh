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

source /opt/app_rpt/config.ini
sourcefile=/opt/app_rpt/config.ini

#    USAGE:  Accept single digit commands from CLI or DTMF with
#    prepended 0 or otherwise proceed with double digits as entered

type=$(echo $0 | cut -d'_' -f2 | cut -d'.' -f1)

if [[ "$1" =~ ^[0] ]]; then
    myvar=$(echo $1 | cut -c2)
    asterisk -rx "rpt cmd $MYNODE $type $myvar"
    exit
elif [[ "$1" != ^[0] ]]; then
    asterisk -rx "rpt cmd $MYNODE $type $1"
    exit
fi
