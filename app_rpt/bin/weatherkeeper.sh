#!/bin/bash

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

# Reach out and grab the latest Weather Underground data
if [ "$FETCHLOCAL" == "1" ]; then # Copy a file from a local hub
    sudo rsync -azr --delete $FETCHPOINT:$WUOUTPUT $WUOUTPUT
elif [ "$FETCHLOCAL" == "0" ]; then # Pull directly from Weather Underground
    curl -s -k https://api.weather.com/v2/pws/observations/current?stationId=$WUSTATION\&format=json\&units=e\&apiKey=$WUAPIKEY -o $WUOUTPUT
else
    exit 1
fi

# Parse the JSON data for weather data using jq
temp=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .temp] | @sh')
windchill=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .windChill] | @sh')
heatindex=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .heatIndex] | @sh')
dewpt=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .dewpt] | @sh')
negtemp=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .temp] | @sh' | cut -d'-' -f2)
negwindchill=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .windChill] | @sh' | cut -d'-' -f2)
negheatindex=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .heatIndex] | @sh' | cut -d'-' -f2)
negdewpt=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .dewpt] | @sh' | cut -d'-' -f2)
windspd=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .windSpeed] | @sh')
windgust=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .windGust] | @sh')
winddir=$(cat $WUOUTPUT | jq -r '.observations[] | [.winddir] | @sh')
humidity=$(cat $WUOUTPUT | jq -r '.observations[] | [.humidity] | @sh')
pressure_left=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .pressure] | @sh' | cut -d'.' -f1)
pressure_right=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .pressure] | @sh' | cut -d'.' -f2)
uv=$(cat $WUOUTPUT | jq -r '.observations[] | [.uv] | @sh' | cut -d'.' -f1)
preciprate_left=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .precipRate] | @sh' | cut -d'.' -f1)
preciprate_right=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .precipRate] | @sh' | cut -d'.' -f2)
preciptotal_left=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .precipTotal] | @sh' | cut -d'.' -f1)
preciptotal_right=$(cat $WUOUTPUT | jq -r '.observations[] | [.imperial | .precipTotal] | @sh' | cut -d'.' -f2)

# Humidity
cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$humidity.ulaw $SNDMALE/percent.ulaw >$SNDWX/humidity.ulaw

# Barometer
cat $SNDMALE/current.ulaw $SNDMALE/pressure.ulaw $SNDMALE/is.ulaw $SNDMALE/$pressure_left.ulaw $SNDMALE/point.ulaw $SNDMALE/$pressure_right.ulaw >$SNDWX/pressure.ulaw

# UV Index
cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$uv.ulaw >$SNDWX/uv.ulaw

# Precipitation Per Hour
cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$preciprate_left.ulaw $SNDMALE/point.ulaw $SNDMALE/$preciprate_right.ulaw $SNDMALE/inch.ulaw $SNDMALE/suffix_s.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/preciprate.ulaw

# Precipitation Total
cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$preciptotal_left.ulaw $SNDMALE/point.ulaw $SNDMALE/$preciptotal_right.ulaw $SNDMALE/inch.ulaw $SNDMALE/suffix_s.ulaw >$SNDWX/preciptotal.ulaw

# Temperature
if [ $temp -lt '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/temperature.ulaw $SNDMALE/is.ulaw $SNDMALE/minus.ulaw $SNDMALE/$negtemp.ulaw $SNDMALE/degrees.ulaw >$SNDWX/temp.ulaw
elif [ $temp -ge '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/temperature.ulaw $SNDMALE/is.ulaw $SNDMALE/$temp.ulaw $SNDMALE/degrees.ulaw >$SNDWX/temp.ulaw
else
    echo "I can't figure out the temperature!"
    exit
fi

# Wind Chill
if [ $temp -lt '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/minus.ulaw $SNDMALE/$negwindchill.ulaw $SNDMALE/degrees.ulaw >$SNDWX/windchill.ulaw
elif [ $temp -ge '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$windchill.ulaw $SNDMALE/degrees.ulaw >$SNDWX/windchill.ulaw
else
    echo "I can't figure out the wind chill!"
    exit
fi

# Heat Index
if [ $temp -lt '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/minus.ulaw $SNDMALE/$negheatindex.ulaw $SNDMALE/degrees.ulaw >$SNDWX/heatindex.ulaw
elif [ $temp -ge '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$heatindex.ulaw $SNDMALE/degrees.ulaw >$SNDWX/heatindex.ulaw
else
    echo "I can't figure out the heat index!"
    exit
fi

# Dew Point
if [ $temp -lt '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/minus.ulaw $SNDMALE/$negdewpt.ulaw $SNDMALE/degrees.ulaw >$SNDWX/dewpt.ulaw
elif [ $temp -ge '0' ]; then
    cat $SNDMALE/current.ulaw $SNDMALE/suffix_ly.ulaw $SNDMALE/indicated.ulaw $SNDMALE/at.ulaw $SNDMALE/$dewpt.ulaw $SNDMALE/degrees.ulaw >$SNDWX/dewpt.ulaw
else
    echo "I can't figure out the dew point!"
    exit
fi

# Wind Direction (North)
if [ $winddir -ge '337' -a $winddir -le '360' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/north.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (Northwest)
elif [ $winddir -ge '294' -a $winddir -le '336' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/north.ulaw $SNDMALE/west.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (West)
elif [ $winddir -ge '247' -a $winddir -le '293' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/west.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (Southwest)
elif [ $winddir -ge '204' -a $winddir -le '246' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/south.ulaw $SNDMALE/west.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (South)
elif [ $winddir -ge '157' -a $winddir -le '203' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/south.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (Southeast)
elif [ $winddir -ge '114' -a $winddir -le '156' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/south.ulaw $SNDMALE/east.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (East)
elif [ $winddir -ge '67' -a $winddir -le '113' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/east.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (Northeast)
elif [ $winddir -ge '24' -a $winddir -le '66' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/north.ulaw $SNDMALE/east.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
# Wind Direction (North)
elif [ $winddir -ge '0' -a $winddir -le '23' ]; then
    cat $SNDMALE/wind.ulaw $SNDMALE/is.ulaw $SNDMALE/out.ulaw $SNDMALE/of.ulaw $SNDMALE/the.ulaw $SNDMALE/north.ulaw $SNDMALE/at.ulaw $SNDMALE/$windspd.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw $SNDMALE/and.ulaw $SNDMALE/gusting_to.ulaw $SNDMALE/$windgust.ulaw $SNDMALE/miles.ulaw $SNDMALE/per.ulaw $SNDMALE/hour.ulaw >$SNDWX/wind.ulaw
else
    echo "I can't figure out the wind direction!"
    exit
fi

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
