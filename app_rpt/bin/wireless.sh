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

# Use configured wireless device (defaults to wlan0 if not set)
wlan_dev="${wlandevice:-wlan0}"

# Get wireless stats with fallback to "0" if unavailable
frequency=$(iwconfig "$wlan_dev" 2>/dev/null | tr -d ' ' | grep Frequency | cut -d':' -f3 | cut -d'A' -f1 || echo "0")
level=$(iwconfig "$wlan_dev" 2>/dev/null | tr -d ' ' | grep Signallevel | cut -d'=' -f3 | cut -d'/' -f1 || echo "0")
power=$(iwconfig "$wlan_dev" 2>/dev/null | tr -d ' ' | grep Tx-Power | cut -d'=' -f3 || echo "0")
quality=$(iwconfig "$wlan_dev" 2>/dev/null | tr -d ' ' | grep LinkQuality | cut -d'=' -f2 | cut -d'/' -f1 || echo "0")
rate=$(iwconfig "$wlan_dev" 2>/dev/null | tr -d '\n' | tr -s ' ' | cut -d' ' -f13,14 | cut -d'=' -f2 | cut -d'/' -f1 | tr -d ' ' || echo "0")

asterisk -rx "rpt localplay $MYNODE rpt/link_condition_is"
"$BINDIR/speaktext.sh" "$quality"
sleep 4
asterisk -rx "rpt localplay $MYNODE rpt/out_of_70"
sleep 3
asterisk -rx "rpt localplay $MYNODE rpt/r_s_s_i_is"
"$BINDIR/speaktext.sh" "$level"
sleep 7
asterisk -rx "rpt localplay $MYNODE rpt/transmit_power_is"
"$BINDIR/speaktext.sh" "$power"
sleep 7
asterisk -rx "rpt localplay $MYNODE rpt/frequency_is"
"$BINDIR/speaktext.sh" "$frequency"
sleep 6
asterisk -rx "rpt localplay $MYNODE rpt/flow_rate_is"
"$BINDIR/speaktext.sh" "$rate"

###VERSION=2.0.7
