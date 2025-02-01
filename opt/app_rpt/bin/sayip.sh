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

landevice=eth0
wlandevice=wlan0
vpndevice=wg0

case $1 in
lan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show $landevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
wlan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show $wlandevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
vpn)
    asterisk -rx "rpt localplay $MYNODE rpt/vpn_ip_address"
    ip=$(ip addr show $vpndevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
wan)
    ip=$(curl -s http://myip.hamvoip.org/ 2>&1)
    asterisk -rx "rpt localplay $MYNODE rpt/wan_ip_address"
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
*) ;;
esac
