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

#    This script adapted from works provided Ramon Gonzalez, KP4TR (2014)

#    Source local variables
source /opt/app_rpt/config.ini
sourcefile=/opt/app_rpt/config.ini

speakfile=/tmp/speakfile

function speak {
    speaktext=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    let speaklen=$(echo "$speaktext" | /usr/bin/wc -m)-1
    counter=0
    rm -f $speakfile.ulaw
    touch $speakfile.ulaw
    while [ $counter -lt $speaklen ]; do
        let counter=counter+1
        character=$(echo "$speaktext" | cut -c$counter )
        if [[ $character =~ ^[A-Za-z_]+$ ]]
            then
            cat $SOUNDS/letters/$character.ulaw >> $speakfile.ulaw
        fi
        if [[ $character =~ ^-?[0-9]+$ ]]
            then
            cat $SOUNDS/digits/$character.ulaw >> $speakfile.ulaw
        fi
        case $character in
            '.') cat $SOUNDS/_male/point.ulaw >> $speakfile.ulaw ;;
            '+') cat $SOUNDS/_male/plus.ulaw >> $speakfile.ulaw ;;
            '-') cat $SOUNDS/_male/minus.ulaw >> $speakfile.ulaw ;;
            '=') cat $SOUNDS/_male/equal.ulaw >> $speakfile.ulaw ;;
            '@') cat $SOUNDS/_male/at.ulaw >> $speakfile.ulaw ;;
            '#') cat $SOUNDS/_male/pound.ulaw >> $speakfile.ulaw ;;
            '*') cat $SOUNDS/_male/star.ulaw >> $speakfile.ulaw ;;
            *) ;;
        esac
    done
    if [ $2 == "File" ]
        then
	exit
    else
	asterisk -rx "rpt localplay $MYNODE $speakfile"
    fi
}

if [ "$1" == "" ]
    then
    echo "$0 <characters>"
    exit
fi

speak "$1" $MYNODE
