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

#    Source local variables
source /opt/app_rpt/config.ini
sourcefile=/opt/app_rpt/config.ini

# Reach out and grab the latest NWS alerts
curl -s -k https://api.weather.gov/alerts/active.atom?zone=$NWSZONE -o $NWSFILE

# Parse the file for message contents
message=`cat $NWSFILE | grep \<cap\:msgType\>Alert\<\/cap\:msgType\> | cut -d'>' -f2 | cut -d'<' -f1 | uniq`
severity=`cat $NWSFILE | grep \<cap\:severity\>Severe\<\/cap\:severity\> | cut -d'>' -f2 | cut -d'<' -f1 | uniq`
urgency=`cat $NWSFILE | grep \<cap\:urgency\>Immediate\<\/cap\:urgency\> | cut -d'>' -f2 | cut -d'<' -f1 | uniq`

if [ "$SEVEREWEATEHR" == "4" ]
    then
        echo "Skipping activation of alerts due to an automatic override!"
        exit
elif [ "$SEVEREWEATHER" == "3" ]
    then
    if [ "$severity" == "Severe" ] && [ "$urgency" == "Immediate" ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" $sourcefile
        $STATEKEEPER severeweather
        echo "Severe Weather Alert Activated!"
        exit
    elif [ "$message" == "Alert" ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=2/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
        $STATEKEEPER weatheralert
        echo "Weather Alert Activated!"
        exit
    else
        exit
    fi
elif [ "$SEVEREWEATHER" == "2" ]
    then
    if [ "$severity" == "Severe" ] && [ "$urgency" == "Immediate" ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=1/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" $sourcefile
        $STATEKEEPER severeweather
        echo "Weather Alert Activated!"
        exit
    elif [ -z $message ] && [ -z $severity ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=1/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        $STATEKEEPER standard
        echo "Weather Alert Deactivated."
        exit
    else
        exit
    fi
elif [ "$SEVEREWEATHER" == "1" ]
    then
    if [ "$message" == "Alert" ] && [ -z $severity ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=2/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
        $STATEKEEPER weatheralert
        echo "Weather Alert Activated!"
        exit
    elif [ -z $message ] && [ -z $severity ]
        then
        sed -i "s/^SCHEDULER=.*$/SCHEDULER=1/g" $sourcefile
        sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
        sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
        asterisk -rx "rpt localplay $MYNODE rpt/cancel_weather_alert"
        sleep 5
        $STATEKEEPER standard
        echo "Weather Alert Deactivated."
        exit
    else
        exit
    fi
elif [ "$SEVEREWEATHER" == "0" ]
    then
        echo "Weather Alert Disabled!"
        exit
    fi
else
    exit
fi
