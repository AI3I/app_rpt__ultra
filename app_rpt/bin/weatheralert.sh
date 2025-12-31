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

# Reach out and grab the latest NWS alerts
curl -s -k "https://api.weather.gov/alerts/active.atom?zone=${NWSZONE}" -o "$NWSFILE"

# Parse the file for message contents
message=$(grep '<cap:msgType>Alert</cap:msgType>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)
severity=$(grep '<cap:severity>Severe</cap:severity>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)
urgency=$(grep '<cap:urgency>Immediate</cap:urgency>' "$NWSFILE" 2>/dev/null | cut -d'>' -f2 | cut -d'<' -f1 | uniq || true)

if [[ "$SEVEREWEATHER" == "3" ]]; then
    if [[ "$severity" == "Severe" ]] && [[ "$urgency" == "Immediate" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
        "$STATEKEEPER" severeweather
        exit 0
    elif [[ "$message" == "Alert" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=2/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        "$STATEKEEPER" weatheralert
        exit 0
    else
        exit 0
    fi
elif [[ "$SEVEREWEATHER" == "2" ]]; then
    if [[ "$severity" == "Severe" ]] && [[ "$urgency" == "Immediate" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
        "$STATEKEEPER" severeweather
        exit 0
    elif [[ -z "$message" ]] && [[ -z "$severity" ]]; then
        sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        "$STATEKEEPER" standard
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
        exit 0
    elif [[ -z "$message" ]] && [[ -z "$severity" ]]; then
        sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=1/g" "$sourcefile"
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        "$STATEKEEPER" standard
        exit 0
    else
        exit 0
    fi
elif [[ "$SEVEREWEATHER" == "0" ]]; then
    exit 0
else
    exit 0
fi

###EDIT: Tue Dec 31 2025
