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
        mysleep=`echo $1 | cut -c3,4,5,6`
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/off"
        echo 0 > /sys/class/gpio/gpio$mygpio/value
        sleep $mysleep
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/on"
        echo 1 > /sys/class/gpio/gpio$mygpio/value
    exit
elif [[ "$1" != ^[0] ]]
    then
        mygpio=`echo $1 | cut -c1,2`
        mysleep=`echo $1 | cut -c3,4,5,6`
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/off"
        echo 0 > /sys/class/gpio/gpio$mygpio/value
        sleep $mysleep
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/on"
        echo 1 > /sys/class/gpio/gpio$mygpio/value
    exit
fi
