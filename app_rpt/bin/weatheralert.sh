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
sourcefile="$CONFIG_FILE"

# ==============================================================================
#    Fetch NWS Alerts
# ==============================================================================

# Reach out and grab the latest NWS alerts
curl -s -k "https://api.weather.gov/alerts/active.atom?zone=${NWSZONE}" -o "$NWSFILE"

# Parse the file for message contents
message=$(grep '<cap:msgType>Alert</cap:msgType>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)
severity=$(grep '<cap:severity>Severe</cap:severity>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)
urgency=$(grep '<cap:urgency>Immediate</cap:urgency>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)

# Extract ALL event types and intelligently select based on severity hierarchy
# Prioritized by: 1) Catastrophic potential, 2) Speed of onset, 3) Life-threatening nature
#
# TIER 1 (CRITICAL - Rapid onset, immediately life-threatening):
#   Tornado, Flash Flood, Tsunami, Radiological, Shelter-In-Place, Volcano
# TIER 2 (SEVERE - Life-threatening, slower onset):
#   Hurricane, Severe Thunderstorm, High/Extreme Wind, Fire, Dust Storm, Storm Surge
# TIER 3 (SERIOUS - Potentially life-threatening, more time to prepare):
#   Blizzard, Winter Storm, Ice Storm, Flood, Extreme Heat/Cold, Gale
# TIER 4 (MODERATE - Property/health risk, ample warning):
#   Snow Squall, Freeze, Lake Effect Snow, other warnings
# TIER 5 (WATCHES - Advance notice)
# TIER 6 (ADVISORIES - Informational)

all_events=$(grep '<cap:event>' "$NWSFILE" 2>/dev/null | sed 's/.*<cap:event>\(.*\)<\/cap:event>.*/\1/' || true)

select_highest_priority_event() {
    local events="$1"
    local result

    # TIER 1: CRITICAL (rapid onset, immediately deadly) - check in priority order
    result=$(echo "$events" | grep -i "radiological.*hazard.*warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "shelter.*place.*warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "tornado warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "tsunami.*warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "flash flood warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "volcano warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi

    # TIER 2: SEVERE (life-threatening, slower onset)
    result=$(echo "$events" | grep -i "hurricane warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "severe thunderstorm warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -iE "(high|extreme) wind warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "fire.*warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "dust storm warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "storm surge warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi

    # TIER 3: SERIOUS (potentially deadly, more time to prepare)
    result=$(echo "$events" | grep -i "blizzard warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "winter storm warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "ice storm warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -iE "^flood warning|river flood warning|areal flood warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -iE "(coastal|lakeshore) flood warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -iE "(extreme|excessive) (heat|cold) warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi
    result=$(echo "$events" | grep -i "gale warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi

    # TIER 4: MODERATE (property/health risk, ample warning)
    result=$(echo "$events" | grep -i "warning" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi

    # TIER 5: WATCHES (advance notice)
    result=$(echo "$events" | grep -i "watch" | head -1); if [[ -n "$result" ]]; then echo "$result"; return; fi

    # TIER 6: ADVISORIES (informational)
    echo "$events" | head -1
}

if [[ -z "$all_events" ]]; then
    event=""
else
    warning_count=$(echo "$all_events" | grep -ic "warning" || echo "0")

    if [[ $warning_count -eq 0 ]]; then
        # No warnings - just use first watch/advisory
        event=$(echo "$all_events" | head -1)
        log "No warnings detected, using: $event"
    elif [[ $warning_count -eq 1 ]]; then
        # Single warning - announce it
        event=$(echo "$all_events" | grep -i "warning")
        log "Single warning detected: $event"
    else
        # Multiple warnings - select highest priority
        event=$(select_highest_priority_event "$all_events")
        log "Multiple warnings ($warning_count) - selected highest priority: $event"
    fi
fi

# ==============================================================================
#    Build Custom Weather Message
# ==============================================================================

build_weather_message() {
    local event_type="$1"
    local message_file="/tmp/weather_alert_message.ulaw"

    # Convert event to lowercase for matching
    local event_lower=$(echo "$event_type" | tr '[:upper:]' '[:lower:]')

    # Check if we have vocabulary to build a specific message
    # NOTE: Patterns verified against official NWS CAP event types (Jan 2026)
    # Source: https://vlab.noaa.gov/web/nws-common-alerting-protocol/cap-documentation
    case "$event_lower" in
        *tornado*warning*)
            # NWS: "Tornado Warning"
            cat "${SOUNDS}/_male/tornado.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: tornado warning"
            ;;
        *tornado*watch*)
            # NWS: "Tornado Watch"
            cat "${SOUNDS}/_male/tornado.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: tornado watch"
            ;;
        *severe*thunderstorm*warning*)
            # NWS: "Severe Thunderstorm Warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/thunderstorm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: severe thunderstorm warning"
            ;;
        *severe*thunderstorm*watch*)
            # NWS: "Severe Thunderstorm Watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/thunderstorm.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: severe thunderstorm watch"
            ;;
        *wind*warning*)
            # NWS: "High Wind Warning", "Extreme Wind Warning" → "high wind warning"
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: high wind warning"
            ;;
        *ice*storm*warning*)
            # NWS: "Ice Storm Warning"
            cat "${SOUNDS}/_male/ice.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: ice storm warning"
            ;;
        *winter*storm*warning*)
            # NWS: "Winter Storm Warning" → "severe snow storm warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: winter storm warning (as severe snow storm warning)"
            ;;
        *winter*storm*watch*)
            # NWS: "Winter Storm Watch" → "severe snow storm watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: winter storm watch (as severe snow storm watch)"
            ;;
        *blizzard*warning*)
            # NWS: "Blizzard Warning" → "severe snow wind warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: blizzard warning (as severe snow wind warning)"
            ;;
        *snow*squall*warning*)
            # NWS: "Snow Squall Warning" → "heavy snow wind warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: snow squall warning (as heavy snow wind warning)"
            ;;
        *freezing*rain*)
            # NWS: "Freezing Rain" (in weather statements)
            cat "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/rain.ulaw" > "$message_file"
            log "Built custom message: freezing rain"
            ;;
        *dust*storm*warning*)
            # NWS: "Dust Storm Warning"
            cat "${SOUNDS}/_male/dust.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: dust storm warning"
            ;;
        *fire*warning*|*fire*weather*warning*)
            # NWS: "Fire Warning", "Fire Weather Warning"
            cat "${SOUNDS}/_male/fire.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: fire warning"
            ;;
        *dense*fog*|*fog*advisory*)
            # NWS: "Dense Fog Advisory" → "heavy fog condition"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/fog.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: dense fog advisory (as heavy fog condition)"
            ;;
        *flash*flood*warning*|*flood*warning*)
            # NWS: "Flash Flood Warning", "Flood Warning" → "heavy rain warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: flood warning (as heavy rain warning)"
            ;;
        *flash*flood*watch*|*flood*watch*)
            # NWS: "Flash Flood Watch", "Flood Watch" → "heavy rain watch"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: flood watch (as heavy rain watch)"
            ;;
        *freeze*warning*|*hard*freeze*warning*)
            # NWS: "Freeze Warning", "Hard Freeze Warning" → "freezing warning"
            if [[ "$event_lower" == *hard* ]]; then
                cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
                log "Built custom message: hard freeze warning (as severe freezing warning)"
            else
                cat "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
                log "Built custom message: freeze warning (as freezing warning)"
            fi
            ;;
        *freeze*watch*|*hard*freeze*watch*)
            # NWS: "Freeze Watch", "Hard Freeze Watch" → "freezing watch"
            if [[ "$event_lower" == *hard* ]]; then
                cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
                log "Built custom message: hard freeze watch (as severe freezing watch)"
            else
                cat "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
                log "Built custom message: freeze watch (as freezing watch)"
            fi
            ;;
        *frost*advisory*)
            # NWS: "Frost Advisory" → "freezing condition"
            cat "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: frost advisory (as freezing condition)"
            ;;
        *coastal*flood*warning*|*lakeshore*flood*warning*)
            # NWS: "Coastal Flood Warning", "Lakeshore Flood Warning" → "heavy rain warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: coastal/lakeshore flood warning (as heavy rain warning)"
            ;;
        *coastal*flood*watch*|*lakeshore*flood*watch*)
            # NWS: "Coastal Flood Watch", "Lakeshore Flood Watch" → "heavy rain watch"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: coastal/lakeshore flood watch (as heavy rain watch)"
            ;;
        *extreme*heat*warning*|*excessive*heat*warning*)
            # NWS: "Extreme Heat Warning", "Excessive Heat Warning" → "severe temperature warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/temperature.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: extreme heat warning (as severe temperature warning)"
            ;;
        *extreme*heat*watch*|*excessive*heat*watch*)
            # NWS: "Extreme Heat Watch", "Excessive Heat Watch" → "severe temperature watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/temperature.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: extreme heat watch (as severe temperature watch)"
            ;;
        *heat*advisory*)
            # NWS: "Heat Advisory" → "high temperature condition"
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/temperature.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: heat advisory (as high temperature condition)"
            ;;
        *extreme*cold*warning*)
            # NWS: "Extreme Cold Warning" → "low temperature warning"
            cat "${SOUNDS}/_male/low.ulaw" "${SOUNDS}/_male/temperature.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: extreme cold warning (as low temperature warning)"
            ;;
        *extreme*cold*watch*)
            # NWS: "Extreme Cold Watch" → "low temperature watch"
            cat "${SOUNDS}/_male/low.ulaw" "${SOUNDS}/_male/temperature.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: extreme cold watch (as low temperature watch)"
            ;;
        *high*wind*watch*)
            # NWS: "High Wind Watch"
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: high wind watch"
            ;;
        *wind*advisory*)
            # NWS: "Wind Advisory" → "wind condition"
            cat "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: wind advisory (as wind condition)"
            ;;
        *blowing*dust*advisory*)
            # NWS: "Blowing Dust Advisory" → "blowing dust condition"
            cat "${SOUNDS}/_male/blowing.ulaw" "${SOUNDS}/_male/dust.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: blowing dust advisory (as blowing dust condition)"
            ;;
        *winter*weather*advisory*)
            # NWS: "Winter Weather Advisory" → "snow condition"
            cat "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: winter weather advisory (as snow condition)"
            ;;
        *avalanche*watch*)
            # NWS: "Avalanche Watch" → "severe snow watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: avalanche watch (as severe snow watch)"
            ;;
        *hurricane*warning*)
            # NWS: "Hurricane Warning" → "severe wind storm warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: hurricane warning (as severe wind storm warning)"
            ;;
        *hurricane*watch*)
            # NWS: "Hurricane Watch" → "severe wind storm watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: hurricane watch (as severe wind storm watch)"
            ;;
        *tropical*storm*warning*)
            # NWS: "Tropical Storm Warning" → "severe wind storm warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: tropical storm warning (as severe wind storm warning)"
            ;;
        *tropical*storm*watch*)
            # NWS: "Tropical Storm Watch" → "severe wind storm watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: tropical storm watch (as severe wind storm watch)"
            ;;
        *tsunami*warning*)
            # NWS: "Tsunami Warning" → "high water warning" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: tsunami warning (as high water warning)"
            ;;
        *tsunami*watch*)
            # NWS: "Tsunami Watch" → "high water watch" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: tsunami watch (as high water watch)"
            ;;
        *storm*surge*warning*)
            # NWS: "Storm Surge Warning" → "high water warning" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: storm surge warning (as high water warning)"
            ;;
        *storm*surge*watch*)
            # NWS: "Storm Surge Watch" → "high water watch" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: storm surge watch (as high water watch)"
            ;;
        *air*quality*alert*)
            # NWS: "Air Quality Alert" → "hazardous air condition"
            cat "${SOUNDS}/_male/hazardous.ulaw" "${SOUNDS}/_male/air.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: air quality alert (as hazardous air condition)"
            ;;
        *rip*current*statement*)
            # NWS: "Rip Current Statement" → "danger water condition" (watt + er = water)
            cat "${SOUNDS}/_male/danger.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: rip current statement (as danger water condition)"
            ;;
        *volcano*warning*)
            # NWS: "Volcano Warning" → "severe fire danger warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/fire.ulaw" "${SOUNDS}/_male/danger.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: volcano warning (as severe fire danger warning)"
            ;;
        *radiological*hazard*warning*)
            # NWS: "Radiological Hazard Warning" → "severe hazardous condition alert"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/hazardous.ulaw" "${SOUNDS}/_male/condition.ulaw" "${SOUNDS}/_male/alert.ulaw" > "$message_file"
            log "Built custom message: radiological hazard warning (as severe hazardous condition alert)"
            ;;
        *shelter*in*place*warning*)
            # NWS: "Shelter In Place Warning" → "maintain secure position"
            cat "${SOUNDS}/_male/maintain.ulaw" "${SOUNDS}/_male/secure.ulaw" "${SOUNDS}/_male/position.ulaw" > "$message_file"
            log "Built custom message: shelter in place warning (as maintain secure position)"
            ;;
        *special*marine*warning*)
            # NWS: "Special Marine Warning" → "severe storm warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: special marine warning (as severe storm warning)"
            ;;
        *special*weather*statement*)
            # NWS: "Special Weather Statement" → "weather condition"
            cat "${SOUNDS}/_male/weather.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: special weather statement (as weather condition)"
            ;;
        *hydrologic*outlook*)
            # NWS: "Hydrologic Outlook" → "heavy rain condition"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: hydrologic outlook (as heavy rain condition)"
            ;;
        *small*craft*advisory*)
            # NWS: "Small Craft Advisory" → "wind condition"
            cat "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: small craft advisory (as wind condition)"
            ;;
        *gale*warning*)
            # NWS: "Gale Warning" → "severe wind warning"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: gale warning (as severe wind warning)"
            ;;
        *gale*watch*)
            # NWS: "Gale Watch" → "severe wind watch"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/wind.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: gale watch (as severe wind watch)"
            ;;
        *storm*warning*)
            # NWS: "Storm Warning" (marine) → "severe storm warning"
            # NOTE: This pattern is intentionally broad to catch marine storm warnings
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/storm.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: storm warning (as severe storm warning)"
            ;;
        *red*flag*warning*)
            # NWS: "Red Flag Warning" → "fire danger warning"
            cat "${SOUNDS}/_male/fire.ulaw" "${SOUNDS}/_male/danger.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: red flag warning (as fire danger warning)"
            ;;
        *lake*effect*snow*warning*|*lake*snow*warning*)
            # NWS: "Lake Effect Snow Warning" → "heavy snow warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: lake effect snow warning (as heavy snow warning)"
            ;;
        *lake*effect*snow*advisory*|*lake*snow*advisory*)
            # NWS: "Lake Effect Snow Advisory" → "snow condition"
            cat "${SOUNDS}/_male/snow.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: lake effect snow advisory (as snow condition)"
            ;;
        *ashfall*warning*)
            # NWS: "Ashfall Warning" → "severe smoke condition"
            cat "${SOUNDS}/_male/severe.ulaw" "${SOUNDS}/_male/smoke.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: ashfall warning (as severe smoke condition)"
            ;;
        *ashfall*advisory*)
            # NWS: "Ashfall Advisory" → "smoke condition"
            cat "${SOUNDS}/_male/smoke.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: ashfall advisory (as smoke condition)"
            ;;
        *heavy*freezing*spray*warning*|*freezing*spray*warning*)
            # NWS: "Heavy Freezing Spray Warning" → "heavy ice warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/ice.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: heavy freezing spray warning (as heavy ice warning)"
            ;;
        *heavy*freezing*spray*advisory*|*freezing*spray*advisory*)
            # NWS: "Heavy Freezing Spray Advisory" → "freezing ice condition"
            cat "${SOUNDS}/_male/freezing.ulaw" "${SOUNDS}/_male/ice.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: heavy freezing spray advisory (as freezing ice condition)"
            ;;
        *marine*weather*statement*)
            # NWS: "Marine Weather Statement" → "water weather condition" (watt + er = water)
            cat "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/weather.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: marine weather statement (as water weather condition)"
            ;;
        *high*surf*warning*)
            # NWS: "High Surf Warning" → "high water warning" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: high surf warning (as high water warning)"
            ;;
        *high*surf*advisory*)
            # NWS: "High Surf Advisory" → "high water condition" (watt + er = water)
            cat "${SOUNDS}/_male/high.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: high surf advisory (as high water condition)"
            ;;
        *hazardous*seas*warning*)
            # NWS: "Hazardous Seas Warning" → "hazardous water warning" (watt + er = water)
            cat "${SOUNDS}/_male/hazardous.ulaw" "${SOUNDS}/_male/watt.ulaw" "${SOUNDS}/_male/suffix_er.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: hazardous seas warning (as hazardous water warning)"
            ;;
        *river*flood*warning*|*areal*flood*warning*)
            # NWS: "River Flood Warning", "Areal Flood Warning" → "heavy rain warning"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/rain.ulaw" "${SOUNDS}/_male/warning.ulaw" > "$message_file"
            log "Built custom message: river/areal flood warning (as heavy rain warning)"
            ;;
        *fire*weather*watch*)
            # NWS: "Fire Weather Watch" → "fire danger watch"
            cat "${SOUNDS}/_male/fire.ulaw" "${SOUNDS}/_male/danger.ulaw" "${SOUNDS}/_male/watch.ulaw" > "$message_file"
            log "Built custom message: fire weather watch (as fire danger watch)"
            ;;
        *dense*smoke*advisory*)
            # NWS: "Dense Smoke Advisory" → "heavy smoke condition"
            cat "${SOUNDS}/_male/heavy.ulaw" "${SOUNDS}/_male/smoke.ulaw" "${SOUNDS}/_male/condition.ulaw" > "$message_file"
            log "Built custom message: dense smoke advisory (as heavy smoke condition)"
            ;;
        *)
            # No custom vocabulary available - fall back to generic message
            # NOTE: Comprehensive NWS event coverage achieved with creative TMS5220 vocabulary!
            # Remaining unmapped events (if any) will use generic messages based on severity.
            log "No custom vocabulary for: $event_type (using generic message)"
            return 1
            ;;
    esac

    # Play the custom message
    asterisk -rx "rpt localplay $MYNODE /tmp/weather_alert_message" &>/dev/null
    return 0
}

# ==============================================================================
#    Process Weather Alerts
# ==============================================================================

if [[ "$SEVEREWEATHER" == "3" ]]; then
    if [[ "$severity" == "Severe" ]] && [[ "$urgency" == "Immediate" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
        "$STATEKEEPER" severeweather

        # Try to build and play custom message, fall back to generic if not possible
        if ! build_weather_message "$event"; then
            asterisk -rx "rpt localplay $MYNODE rpt/severe_weather_alert" &>/dev/null
        fi

        # Log the state change with event type
        log "NWS Alert: $event (severity=$severity, urgency=$urgency)"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), standard, severeweather, nws_alert:$event, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    elif [[ "$message" == "Alert" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=2/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        "$STATEKEEPER" weatheralert

        # Try to build and play custom message, fall back to generic if not possible
        if ! build_weather_message "$event"; then
            cat "${SOUNDS}/_male/weather.ulaw" "${SOUNDS}/_male/alert.ulaw" > /tmp/weather_alert_message.ulaw
            asterisk -rx "rpt localplay $MYNODE /tmp/weather_alert_message" &>/dev/null
        fi

        log "NWS Alert: $event"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), standard, weatheralert, nws_alert:$event, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    else
        exit 0
    fi
elif [[ "$SEVEREWEATHER" == "2" ]]; then
    if [[ "$severity" == "Severe" ]] && [[ "$urgency" == "Immediate" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
        "$STATEKEEPER" severeweather

        if ! build_weather_message "$event"; then
            asterisk -rx "rpt localplay $MYNODE rpt/severe_weather_alert" &>/dev/null
        fi

        log "NWS Alert upgraded: $event (severity=$severity, urgency=$urgency)"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), weatheralert, severeweather, nws_alert:$event, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    elif [[ -z "$message" ]] && [[ -z "$severity" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        "$STATEKEEPER" standard

        log "NWS Alert cleared"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), weatheralert, standard, nws_clear, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    else
        exit 0
    fi
elif [[ "$SEVEREWEATHER" == "1" ]]; then
    if [[ "$message" == "Alert" ]] && [[ -z "$severity" ]]; then
        sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=0/g" "$sourcefile"
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=2/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        "$STATEKEEPER" weatheralert

        log "NWS Alert downgraded: $event"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), severeweather, weatheralert, nws_downgrade:$event, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    elif [[ -z "$message" ]] && [[ -z "$severity" ]]; then
        sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=1/g" "$sourcefile"
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        "$STATEKEEPER" standard

        log "NWS Alert cleared"
        echo "$(date '+%Y-%m-%d %H:%M:%S'), severeweather, standard, nws_clear, ${MYNODE}" >> /var/log/state_history.log
        exit 0
    else
        exit 0
    fi
elif [[ "$SEVEREWEATHER" == "0" ]]; then
    exit 0
else
    exit 0
fi

###VERSION=2.0.5
