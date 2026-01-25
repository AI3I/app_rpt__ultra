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

# Validate arguments
if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    log_error "Usage: gpio.sh <command> <gpio_number>"
    exit 1
fi

if [[ "$2" =~ ^0 ]]; then
    mygpio=$(echo "$2" | cut -c2)
else
    mygpio=$(echo "$2" | cut -c1,2)
fi

# Validate GPIO number (0-27 for Raspberry Pi)
if [[ ! "$mygpio" =~ ^[0-9]+$ ]] || [[ "$mygpio" -lt 0 ]] || [[ "$mygpio" -gt 27 ]]; then
    log_error "Invalid GPIO number: $mygpio (must be 0-27)"
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
fi

case "$1" in
direction) # GPIO Direction
    myvar=$(echo "$2" | cut -c3)
    if [[ "$myvar" == "1" ]]; then
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/in"
        echo in >"/sys/class/gpio/gpio${mygpio}/direction"
    elif [[ "$myvar" == "0" ]]; then
        asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_direction"
        asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
        asterisk -rx "rpt localplay $MYNODE _male/out"
        echo out >"/sys/class/gpio/gpio${mygpio}/direction"
    fi
    exit 0
    ;;
export) # Export
    asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_set"
    asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
    echo "$mygpio" >/sys/class/gpio/export
    exit 0
    ;;
sleep) # Sleep
    mysleep=$(echo "$2" | cut -c3,4,5,6)
    asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
    asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
    asterisk -rx "rpt localplay $MYNODE _male/off"
    echo 0 >"/sys/class/gpio/gpio${mygpio}/value"
    sleep "$mysleep"
    asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
    asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
    asterisk -rx "rpt localplay $MYNODE _male/on"
    echo 1 >"/sys/class/gpio/gpio${mygpio}/value"
    exit 0
    ;;
toggle) # Toggle On/Off
    asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_operation"
    asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
    gpio unexport "$mygpio"
    sleep 3
    echo "$mygpio" >/sys/class/gpio/export
    exit 0
    ;;
unexport) # Un-Export
    asterisk -rx "rpt localplay $MYNODE rpt/g_p_i_o_set"
    asterisk -rx "rpt localplay $MYNODE digits/$mygpio"
    gpio unexport "$mygpio" 2>/dev/null || true
    exit 0
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.6
