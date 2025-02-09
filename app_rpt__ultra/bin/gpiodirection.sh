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


if [[ "$1" =~ ^[0] ]]
    then
        mygpio=`echo $1 | cut -c2`
        direction=`echo $1 | cut -c3`
        if [ "$direction" == "1" ]
            then
            asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
            asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
            asterisk -rx "rpt localplay $MYNODE _male/in"
            echo in > /sys/class/gpio/gpio$mygpio/direction
        elif [ "$direction" == "0" ]
            then
            asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
            asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
            asterisk -rx "rpt localplay $MYNODE _male/out"
            echo out > /sys/class/gpio/gpio$mygpio/direction
        fi
elif [[ "$1" != ^[0] ]]
    then
        mygpio=`echo $1 | cut -c1,2`
        direction=`echo $1 | cut -c3`
        if [ "$direction" == "1" ]
            then
            asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
            asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
            asterisk -rx "rpt localplay $MYNODE _male/in"
            echo in > /sys/class/gpio/gpio$mygpio/direction
        elif [ "$direction" == "0" ]
            then
            asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
            asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
            asterisk -rx "rpt localplay $MYNODE _male/out"
            echo out > /sys/class/gpio/gpio$mygpio/direction
        fi
    exit
fi
