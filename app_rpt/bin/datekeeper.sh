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

dow=$(date +%A | tr '[:upper:]' '[:lower:]')
month=$(date +%B | tr '[:upper:]' '[:lower:]')
day=$(date +%-e | tr -d ' ')
year=$(date +%y)

# Today is <day of week>, <month> <day>, <year>
cat "${SNDMALE}/today.ulaw" \
    "${SNDMALE}/is.ulaw" \
    "${SNDMALE}/${dow}.ulaw" \
    "${SNDMALE}/${month}.ulaw" \
    "${SNDMALE}/${day}.ulaw" \
    "${SNDFX}/pause.ulaw" \
    "${SNDMALE}/2000.ulaw" \
    "${SNDMALE}/${year}.ulaw" \
    > "${SNDRPT}/current_date.ulaw"

###VERSION=2.0.5
