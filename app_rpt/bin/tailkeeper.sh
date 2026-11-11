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

TAILLINK="$SOUNDS/tail_message.ulaw"

# Print one random file from the arguments that actually exists (nothing if
# none do).  A slot nobody has recorded must never be linked: app_rpt would
# play it as silence and log "tail_message does not exist".
pick_existing() {
    local f
    local -a have=()
    for f in "$@"; do
        [[ -f "$f" ]] && have+=("$f")
    done
    if [[ ${#have[@]} -gt 0 ]]; then
        shuf -n 1 -e "${have[@]}"
    fi
}

# Point tail_message.ulaw at the chosen file, or remove the link (logging only
# when it changes, since this runs every minute) when nothing is available.
set_tail() {
    if [[ -n "$1" ]]; then
        ln -sf "$1" "$TAILLINK"
    elif [[ -L "$TAILLINK" || -e "$TAILLINK" ]]; then
        rm -f "$TAILLINK"
        log_error "No tail message recordings available; tail_message removed until one is recorded"
    fi
    exit 0
}

# Severe weather alerts take priority when their recording exists; otherwise
# fall through to the normal tail rather than going silent.
if [[ "$SEVEREWEATHER" == "1" ]] && [[ -f "$SOUNDS/${SVWXALERT}.ulaw" ]]; then
    set_tail "$SOUNDS/${SVWXALERT}.ulaw"
elif [[ "$SEVEREWEATHER" == "2" ]] && [[ -f "$SOUNDS/${RTWXALERT}.ulaw" ]]; then
    set_tail "$SOUNDS/${RTWXALERT}.ulaw"
fi

if [[ "$ENABLETAIL" != "1" ]]; then
    exit 0
fi

# Tail message: the configured slot, or a random recorded slot (1-9) when rotating
if [[ "$ROTATETMSG" == "0" ]]; then
    tailmsg=$(pick_existing "$SOUNDS/tails/tail_message_${TAILMSG}.ulaw")
elif [[ "$ROTATETMSG" == "1" ]]; then
    tailmsg=$(pick_existing "$SOUNDS"/tails/tail_message_{1..9}.ulaw)
else
    exit 0
fi

# Time and temperature readbacks share the rotation equally with the tail
# message, as before; missing files are simply left out.
candidates=()
[[ "$ENABLETIME" == "1" ]] && candidates+=("$SOUNDS/${TIMEMSG}.ulaw")
[[ "$ENABLETEMP" == "1" ]] && candidates+=("$SOUNDS/${TEMPMSG}.ulaw")
[[ -n "$tailmsg" ]] && candidates+=("$tailmsg")

if [[ ${#candidates[@]} -gt 0 ]]; then
    set_tail "$(pick_existing "${candidates[@]}")"
else
    set_tail ""
fi

###VERSION=2.0.9
