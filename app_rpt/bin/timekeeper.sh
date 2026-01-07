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

# ==============================================================================
#    Helper Function
# ==============================================================================

# Build time announcement audio
# Usage: build_time_audio "greeting" "am_pm" ["extra_file"]
build_time_audio() {
    local greeting="$1"
    local ampm="$2"
    local extra="${3:-}"
    local hour
    hour=$(date +%l | tr -d ' ')
    local mins
    mins=$(date +%M)

    if [[ -n "$extra" ]]; then
        cat "$SNDFEMALE/${greeting}.ulaw" "$SNDFEMALE/pause.ulaw" \
            "$SNDFEMALE/the_time_is.ulaw" "$SNDFEMALE/${hour}.ulaw" \
            "$SNDFEMALE/${mins}.ulaw" "$SNDFEMALE/${ampm}.ulaw" \
            "$SNDFEMALE/pause.ulaw" "$extra" > "$SNDRPT/current_time.ulaw"
    else
        cat "$SNDFEMALE/${greeting}.ulaw" "$SNDFEMALE/pause.ulaw" \
            "$SNDFEMALE/the_time_is.ulaw" "$SNDFEMALE/${hour}.ulaw" \
            "$SNDFEMALE/${mins}.ulaw" "$SNDFEMALE/${ampm}.ulaw" > "$SNDRPT/current_time.ulaw"
    fi
}

# ==============================================================================
#    Main Logic
# ==============================================================================

hours=$(date +%k)

# Determine evening cutoff based on DST
# perl returns 0 (success) during standard time, 1 during DST
if perl -e 'exit ((localtime)[8])'; then
    evening_start=17  # DST: evening starts at 5 PM
else
    evening_start=18  # Standard: evening starts at 6 PM
fi

# Build time announcement based on time of day
if [[ $hours -ge $evening_start ]] && [[ $hours -le 23 ]]; then
    build_time_audio "good_evening" "p_m"
elif [[ $hours -ge 12 ]] && [[ $hours -lt $evening_start ]]; then
    build_time_audio "good_afternoon" "p_m"
elif [[ $hours -ge 6 ]] && [[ $hours -lt 12 ]]; then
    build_time_audio "good_morning" "a_m"
elif [[ $hours -ge 0 ]] && [[ $hours -lt 6 ]]; then
    build_time_audio "good_morning" "a_m" "$SNDTAIL/why_are_you_up.ulaw"
fi

###VERSION=2.0.3
