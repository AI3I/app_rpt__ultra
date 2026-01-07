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

#    PURPOSE:  Read messages from table (as defined in messagetable.txt).

if [[ -z "$1" ]]; then
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
fi

# Special handling for slot 00: Play CW ID using rpt.conf parameters
if [[ "$1" == "00" ]]; then
    asterisk -rx "rpt playback $MYNODE |m"
    exit 0
fi

# Use grep -F for fixed string matching to avoid regex injection
msgid=$(grep -F "$1 " "$MSGTBL" | head -1 | cut -d' ' -f2)

if [[ -n "$msgid" ]]; then
    asterisk -rx "rpt localplay $MYNODE $msgid"
else
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
fi

###VERSION=2.0.5
