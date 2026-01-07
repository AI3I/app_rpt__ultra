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
#    Helper Functions
# ==============================================================================

# Safely extract a value from the Weather Underground JSON
# Usage: wx_get "path.to.value"
wx_get() {
    local result
    result=$(jq -r ".observations[0] | $1 // empty" < "$WUOUTPUT" 2>/dev/null)
    # Remove quotes that @sh adds and handle null/empty
    result="${result//\'/}"
    if [[ -z "$result" || "$result" == "null" ]]; then
        echo "0"
    else
        echo "$result"
    fi
}

# Build an audio file from sound segments
# Usage: build_audio "output_file" "segment1" "segment2" ...
build_audio() {
    local output="$1"
    shift
    local files=()
    for seg in "$@"; do
        if [[ -f "$seg" ]]; then
            files+=("$seg")
        else
            log_error "Missing sound file: $seg"
        fi
    done
    if [[ ${#files[@]} -gt 0 ]]; then
        cat "${files[@]}" > "$output"
    fi
}

# ==============================================================================
#    Fetch Weather Data
# ==============================================================================

# Reach out and grab the latest Weather Underground data
if [[ "$FETCHLOCAL" == "1" ]]; then
    # Copy a file from a local hub
    if ! sudo rsync -azr --delete "$FETCHPOINT:$WUOUTPUT" "$WUOUTPUT" 2>/dev/null; then
        log_error "Failed to fetch weather data from $FETCHPOINT"
        exit 1
    fi
elif [[ "$FETCHLOCAL" == "0" ]]; then
    # Pull directly from Weather Underground
    if [[ -z "${WUAPIKEY:-}" || "$WUAPIKEY" == "empty" ]]; then
        log "Weather Underground API key not configured, skipping"
        exit 0
    fi
    if ! curl -s -k --fail --max-time 30 \
        "https://api.weather.com/v2/pws/observations/current?stationId=${WUSTATION}&format=json&units=e&apiKey=${WUAPIKEY}" \
        -o "$WUOUTPUT" 2>/dev/null; then
        log_error "Failed to fetch weather data from Weather Underground API"
        exit 1
    fi
else
    log_error "Invalid FETCHLOCAL value: $FETCHLOCAL"
    exit 1
fi

# Validate the JSON response
if [[ ! -s "$WUOUTPUT" ]]; then
    log_error "Weather data file is empty: $WUOUTPUT"
    exit 1
fi

if ! jq -e '.observations[0]' < "$WUOUTPUT" &>/dev/null; then
    log_error "Invalid or empty weather data in: $WUOUTPUT"
    exit 1
fi

# ==============================================================================
#    Parse Weather Data
# ==============================================================================

# Parse the JSON data using jq
temp=$(wx_get ".imperial.temp")
windchill=$(wx_get ".imperial.windChill")
heatindex=$(wx_get ".imperial.heatIndex")
dewpt=$(wx_get ".imperial.dewpt")
windspd=$(wx_get ".imperial.windSpeed")
windgust=$(wx_get ".imperial.windGust")
winddir=$(wx_get ".winddir")
humidity=$(wx_get ".humidity")
pressure=$(wx_get ".imperial.pressure")
uv=$(wx_get ".uv")
preciprate=$(wx_get ".imperial.precipRate")
preciptotal=$(wx_get ".imperial.precipTotal")

# Handle negative values
negtemp="${temp#-}"
negwindchill="${windchill#-}"
negheatindex="${heatindex#-}"
negdewpt="${dewpt#-}"

# Split decimal values
pressure_left="${pressure%%.*}"
pressure_right="${pressure#*.}"
preciprate_left="${preciprate%%.*}"
preciprate_right="${preciprate#*.}"
preciptotal_left="${preciptotal%%.*}"
preciptotal_right="${preciptotal#*.}"
uv="${uv%%.*}"

# ==============================================================================
#    UV Index Warning Logic (8+ = dangerous)
# ==============================================================================

if [[ $uv -ge 11 ]]; then
    # UV 11+ = EXTREME: "severe U V warning"
    build_audio "$SNDWX/uv_warning.ulaw" \
        "$SNDMALE/severe.ulaw" "$SNDMALE/u.ulaw" "$SNDMALE/v.ulaw" "$SNDMALE/warning.ulaw"
    log "UV index $uv (EXTREME) - severe U V warning generated"
elif [[ $uv -ge 8 ]]; then
    # UV 8-10 = VERY HIGH: "high U V warning"
    build_audio "$SNDWX/uv_warning.ulaw" \
        "$SNDMALE/high.ulaw" "$SNDMALE/u.ulaw" "$SNDMALE/v.ulaw" "$SNDMALE/warning.ulaw"
    log "UV index $uv (VERY HIGH) - high U V warning generated"
else
    # UV < 8: Remove any existing warning file
    rm -f "$SNDWX/uv_warning.ulaw" 2>/dev/null
fi

# ==============================================================================
#    Build Audio Files
# ==============================================================================

# Humidity: "Currently indicated at X percent"
build_audio "$SNDWX/humidity.ulaw" \
    "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
    "$SNDMALE/at.ulaw" "$SNDMALE/${humidity}.ulaw" "$SNDMALE/percent.ulaw"

# Barometer: "Current pressure is X point Y"
build_audio "$SNDWX/pressure.ulaw" \
    "$SNDMALE/current.ulaw" "$SNDMALE/pressure.ulaw" "$SNDMALE/is.ulaw" \
    "$SNDMALE/${pressure_left}.ulaw" "$SNDMALE/point.ulaw" "$SNDMALE/${pressure_right}.ulaw"

# UV Index: "Currently indicated at X"
build_audio "$SNDWX/uv.ulaw" \
    "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
    "$SNDMALE/at.ulaw" "$SNDMALE/${uv}.ulaw"

# Precipitation Rate: "Currently indicated at X point Y inches per hour"
build_audio "$SNDWX/preciprate.ulaw" \
    "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
    "$SNDMALE/at.ulaw" "$SNDMALE/${preciprate_left}.ulaw" "$SNDMALE/point.ulaw" \
    "$SNDMALE/${preciprate_right}.ulaw" "$SNDMALE/inch.ulaw" "$SNDMALE/suffix_s.ulaw" \
    "$SNDMALE/per.ulaw" "$SNDMALE/hour.ulaw"

# Precipitation Total: "Currently indicated at X point Y inches"
build_audio "$SNDWX/preciptotal.ulaw" \
    "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
    "$SNDMALE/at.ulaw" "$SNDMALE/${preciptotal_left}.ulaw" "$SNDMALE/point.ulaw" \
    "$SNDMALE/${preciptotal_right}.ulaw" "$SNDMALE/inch.ulaw" "$SNDMALE/suffix_s.ulaw"

# Temperature: "Current temperature is [minus] X degrees"
if [[ $temp -lt 0 ]]; then
    build_audio "$SNDWX/temp.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/temperature.ulaw" "$SNDMALE/is.ulaw" \
        "$SNDMALE/minus.ulaw" "$SNDMALE/${negtemp}.ulaw" "$SNDMALE/degrees.ulaw"
else
    build_audio "$SNDWX/temp.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/temperature.ulaw" "$SNDMALE/is.ulaw" \
        "$SNDMALE/${temp}.ulaw" "$SNDMALE/degrees.ulaw"
fi

# Wind Chill: "Currently indicated at [minus] X degrees"
if [[ $windchill -lt 0 ]]; then
    build_audio "$SNDWX/windchill.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/minus.ulaw" "$SNDMALE/${negwindchill}.ulaw" "$SNDMALE/degrees.ulaw"
else
    build_audio "$SNDWX/windchill.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/${windchill}.ulaw" "$SNDMALE/degrees.ulaw"
fi

# Heat Index: "Currently indicated at [minus] X degrees"
if [[ $heatindex -lt 0 ]]; then
    build_audio "$SNDWX/heatindex.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/minus.ulaw" "$SNDMALE/${negheatindex}.ulaw" "$SNDMALE/degrees.ulaw"
else
    build_audio "$SNDWX/heatindex.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/${heatindex}.ulaw" "$SNDMALE/degrees.ulaw"
fi

# Dew Point: "Currently indicated at [minus] X degrees"
if [[ $dewpt -lt 0 ]]; then
    build_audio "$SNDWX/dewpt.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/minus.ulaw" "$SNDMALE/${negdewpt}.ulaw" "$SNDMALE/degrees.ulaw"
else
    build_audio "$SNDWX/dewpt.ulaw" \
        "$SNDMALE/current.ulaw" "$SNDMALE/suffix_ly.ulaw" "$SNDMALE/indicated.ulaw" \
        "$SNDMALE/at.ulaw" "$SNDMALE/${dewpt}.ulaw" "$SNDMALE/degrees.ulaw"
fi

# ==============================================================================
#    Wind Direction
# ==============================================================================

# Determine cardinal direction from degrees
get_wind_direction() {
    local dir=$1
    if [[ $dir -ge 337 ]] || [[ $dir -le 23 ]]; then
        echo "north"
    elif [[ $dir -ge 24 ]] && [[ $dir -le 66 ]]; then
        echo "north east"
    elif [[ $dir -ge 67 ]] && [[ $dir -le 113 ]]; then
        echo "east"
    elif [[ $dir -ge 114 ]] && [[ $dir -le 156 ]]; then
        echo "south east"
    elif [[ $dir -ge 157 ]] && [[ $dir -le 203 ]]; then
        echo "south"
    elif [[ $dir -ge 204 ]] && [[ $dir -le 246 ]]; then
        echo "south west"
    elif [[ $dir -ge 247 ]] && [[ $dir -le 293 ]]; then
        echo "west"
    elif [[ $dir -ge 294 ]] && [[ $dir -le 336 ]]; then
        echo "north west"
    else
        echo "north"
    fi
}

# Build wind direction audio files array
direction=$(get_wind_direction "$winddir")
dir_files=()
for word in $direction; do
    dir_files+=("$SNDMALE/${word}.ulaw")
done

# Wind: "Wind is out of the <direction> at X miles per hour and gusting to Y miles per hour"
build_audio "$SNDWX/wind.ulaw" \
    "$SNDMALE/wind.ulaw" "$SNDMALE/is.ulaw" "$SNDMALE/out.ulaw" "$SNDMALE/of.ulaw" \
    "$SNDMALE/the.ulaw" "${dir_files[@]}" "$SNDMALE/at.ulaw" "$SNDMALE/${windspd}.ulaw" \
    "$SNDMALE/miles.ulaw" "$SNDMALE/per.ulaw" "$SNDMALE/hour.ulaw" "$SNDMALE/and.ulaw" \
    "$SNDMALE/gusting_to.ulaw" "$SNDMALE/${windgust}.ulaw" "$SNDMALE/miles.ulaw" \
    "$SNDMALE/per.ulaw" "$SNDMALE/hour.ulaw"

log "Weather data updated successfully"

###VERSION=2.0.4
