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

source /opt/app_rpt/config.ini
sourcefile=/opt/app_rpt/config.ini

#    USAGE:  Accept single digit commands from CLI or DTMF with
#    prepended 0 or otherwise proceed with double digits as entered


if [[ "$2" =~ ^[0] ]]; then
    myvar=$(echo $2 | cut -c2)
elif [[ "$2" != ^[0] ]]; then
    myvar=$(echo $2)
fi


case $1 in
cop) # Control Operator Commands
    asterisk -rx "rpt cmd $MYNODE cop $myvar"
    exit
    ;;
ilink) # Internet Linking Commands
    asterisk -rx "rpt cmd $MYNODE ilink $myvar"
    exit
    ;;
remote) # Remote Base Commands
    asterisk -rx "rpt cmd $MYNODE remote $myvar"
    exit
    ;;
status) # Status Commands
    asterisk -rx "rpt cmd $MYNODE status $myvar"
    exit
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
    ;;
esac

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
