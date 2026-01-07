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

case "$1" in
network) # Network Restart
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/start_internet"
    sleep 2
    systemctl restart NetworkManager
    exit 0
    ;;
lan) # Wireline Interface Restart
    if [[ -z "${landevice:-}" ]]; then
        log_error "landevice not configured"
        asterisk -rx "rpt localplay $MYNODE rpt/program_error"
        exit 1
    fi
    asterisk -rx "rpt localplay $MYNODE rpt/stop_and_start_eth0"
    ip link set "$landevice" down
    sleep 5
    ip link set "$landevice" up
    exit 0
    ;;
wlan) # Wireless Interface Restart
    if [[ -z "${wlandevice:-}" ]]; then
        log_error "wlandevice not configured"
        asterisk -rx "rpt localplay $MYNODE rpt/program_error"
        exit 1
    fi
    asterisk -rx "rpt localplay $MYNODE rpt/stop_and_start_wlan0"
    ip link set "$wlandevice" down
    sleep 5
    ip link set "$wlandevice" up
    exit 0
    ;;
openvpn) # OpenVPN Restart (if installed and enabled)
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/stop_and_start_v_p_n"
    sleep 5
    systemctl restart openvpn@client
    exit 0
    ;;
wireguard) # WireGuard Restart (if installed and enabled)
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/stop_and_start_v_p_n"
    sleep 5
    systemctl restart wg-quick@wg0
    exit 0
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.4
