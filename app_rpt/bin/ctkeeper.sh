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

#    PURPOSE:  Allow changing courtesy tones from table of courtesy tones
#    defined in rpt.conf (template: 00-99) and announce change locally.

case "$1" in
linkunkeyct)
    sed -i.bkp "s/^linkunkeyct=ct.*$/linkunkeyct=ct${2}/g" "$RPTCONF"
    "${BINDIR}/speaktext.sh" "LUCT${2}"
    sleep 5
    asterisk -rx "module reload"
    ;;
remotect)
    sed -i.bkp "s/^remotect=ct.*$/remotect=ct${2}/g" "$RPTCONF"
    "${BINDIR}/speaktext.sh" "RMCT${2}"
    sleep 5
    asterisk -rx "module reload"
    ;;
unlinkedct)
    sed -i.bkp "s/^unlinkedct=ct.*$/unlinkedct=ct${2}/g" "$RPTCONF"
    "${BINDIR}/speaktext.sh" "ULCT${2}"
    sleep 5
    asterisk -rx "module reload"
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.1
