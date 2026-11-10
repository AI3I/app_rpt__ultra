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

#    PURPOSE:  Ability to generate messages from CLI or DTMF dynamically without having to directly edit files.
#
#    CW ID:  00 D <CW character> * <CW character> * <CW character>                      ... uses characters.txt (2 digits)
#    USAGE:  <MSG slot> D <vocabulary word> * <vocabulary word> * <vocabulary word>     ... uses vocabulary.txt (3 digits)
#           ...'D' is a delimiter from the CW ID or message slot
#           ...'*' is a delimiter between characters or words

if [[ -z "${1:-}" ]]; then
    die_with_error "No argument provided"
fi

idstring="${1:0:2}"
if [[ "${1:2:1}" != "D" ]]; then
    die_with_error "Invalid message format: $1 (expected <slot>D<codes>, nothing changed)"
fi
rewrite=$(echo "$1" | cut -d'D' -f2 | sed "s/*/ /g")
cwmsg="${BASEDIR}/lib/cwmsg_${MYNODE}"
voicemsg="${BASEDIR}/lib/voicemsg_${MYNODE}"

if [[ "$idstring" == "00" ]]; then
    : > "$cwmsg"
    for i in $rewrite; do
        char=$(grep "^${i} " "$CWCHARS" 2>/dev/null | head -1 | cut -d' ' -f2 || true)
        if [[ -z "$char" ]]; then
            die_with_error "Unknown CW character code: $i (CW ID not changed)"
        fi
        printf '%s' "$char" >> "$cwmsg"
    done
    cwid=$(cat "$cwmsg")
    if [[ -z "$cwid" ]]; then
        die_with_error "No CW characters given (CW ID not changed)"
    fi
    sed -i "s/^idtalkover=.*$/idtalkover=|i$cwid/g" "$RPTCONF"
    : > "$cwmsg"
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_w_i_d"
    exit 0
else
    msgid=$(grep "^${idstring} " "$MSGTBL" 2>/dev/null | head -1 | cut -d' ' -f2 || true)
    if [[ -z "$msgid" ]]; then
        die_with_error "Invalid message slot: $idstring"
    fi
    # Resolve every code before touching the slot: a typo must not replace a
    # transmitted ID or message with silence or a partial phrase.
    : > "$voicemsg"
    for i in $rewrite; do
        word=$(grep "^${i} " "$VOCAB" 2>/dev/null | head -1 | cut -d' ' -f2 || true)
        if [[ -z "$word" ]]; then
            die_with_error "Unknown vocabulary code: $i (slot $idstring not changed)"
        fi
        if [[ ! -f "$word" ]]; then
            die_with_error "Missing sound file for code $i: $word (slot $idstring not changed)"
        fi
        echo "$word" >> "$voicemsg"
    done
    if [[ ! -s "$voicemsg" ]]; then
        die_with_error "No vocabulary codes given (slot $idstring not changed)"
    fi
    # Build under a temporary name, then swap it in
    tmpmsg="${SOUNDS}/${msgid}.ulaw.tmp.$$"
    if ! xargs -d '\n' cat < "$voicemsg" > "$tmpmsg"; then
        rm -f "$tmpmsg"
        die_with_error "Failed to build slot $idstring (not changed)"
    fi
    mv -f "$tmpmsg" "${SOUNDS}/${msgid}.ulaw"
    : > "$voicemsg"
    if [[ "$idstring" -le "10" ]]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_i_d"
        sleep 1
        "$BINDIR/speaktext.sh" "$idstring"
        exit 0
    elif [[ "$idstring" -le "19" ]]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_t_m"
        sleep 1
        "$BINDIR/speaktext.sh" "$idstring"
        exit 0
    elif [[ "$idstring" -le "50" ]]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_message"
        sleep 1
        "$BINDIR/speaktext.sh" "$idstring"
        exit 0
    else
        die_with_error "Invalid message slot: $idstring (must be 01-50)"
    fi
fi

###VERSION=2.0.8
