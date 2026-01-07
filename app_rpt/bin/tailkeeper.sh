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

if [[ "$SEVEREWEATHER" == "1" ]]; then
    ln -sf "$SOUNDS/${SVWXALERT}.ulaw" "$SOUNDS/tail_message.ulaw"
    exit 0
elif [[ "$SEVEREWEATHER" == "2" ]]; then
    ln -sf "$SOUNDS/${RTWXALERT}.ulaw" "$SOUNDS/tail_message.ulaw"
    exit 0
elif [[ "$ENABLETAIL" == "1" ]]; then
    if [[ "$ROTATETMSG" == "0" ]]; then
        if [[ "$ENABLETEMP" == "1" ]] && [[ "$ENABLETIME" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TIMEMSG}.ulaw" "$SOUNDS/${TEMPMSG}.ulaw" "$SOUNDS/tail_message_${TAILMSG}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        elif [[ "$ENABLETEMP" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TEMPMSG}.ulaw" "$SOUNDS/tail_message_${TAILMSG}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        elif [[ "$ENABLETIME" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TIMEMSG}.ulaw" "$SOUNDS/tail_message_${TAILMSG}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        else
            ln -sf "$SOUNDS/tail_message_${TAILMSG}.ulaw" "$SOUNDS/tail_message.ulaw"
            exit 0
        fi
    elif [[ "$ROTATETMSG" == "1" ]]; then
        tailchurn=$(shuf -i1-9 -n1) # Randomize Tail Messages 1 through 9
        if [[ "$ENABLETEMP" == "1" ]] && [[ "$ENABLETIME" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TIMEMSG}.ulaw" "$SOUNDS/${TEMPMSG}.ulaw" "$SOUNDS/tail_message_${tailchurn}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        elif [[ "$ENABLETEMP" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TEMPMSG}.ulaw" "$SOUNDS/tail_message_${tailchurn}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        elif [[ "$ENABLETIME" == "1" ]]; then
            ln -sf "$(shuf -n 1 -e "$SOUNDS/${TIMEMSG}.ulaw" "$SOUNDS/tail_message_${tailchurn}.ulaw")" "$SOUNDS/tail_message.ulaw"
            exit 0
        else
            ln -sf "$SOUNDS/tail_message_${tailchurn}.ulaw" "$SOUNDS/tail_message.ulaw"
            exit 0
        fi
    else
        exit 0
    fi
else
    exit 0
fi

###VERSION=2.0.4
