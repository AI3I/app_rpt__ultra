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

#    PURPOSE:  Ability to generate courtesy tones from CLI or DTMF dynamically without having to directly edit file.
#
#    USAGE:  <CT slot> A <vocabulary word>  use word from vocabulary (vocabulary.txt)
#            <CT slot> B <character>        use character from CW table (characters.txt)
#            <CT slot> C <tone 1> * <tone 2> * <duration> * <amplitude> D <tone 1> * <tone 2> * <duration> * <amplitude>
#                        ...'D' is a delimiter to allow multiple tones to be strung together
#    SLOTS:  01-95  : standard courtesy tones
#            96     : remotemon
#            97     : remotetx
#            98     : cmdmode
#            99     : functcomplete

type=$(echo $1 | cut -c3)
ct=$(echo $1 | cut -c1,2)

if [ -z $1 ]; then
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
fi

if [ $ct -eq '99' ]; then
    tone=functcomplete
elif [ $ct -eq '98' ]; then
    tone=cmdmode
elif [ $ct -eq '97' ]; then
    tone=remotetx
elif [ $ct -eq '96' ]; then
    tone=remotemon
elif [ $ct -le "95" ]; then
    tone=ct$ct
else
    exit
fi

if [ $type == "C" ]; then
    rewrite=$(echo $1 | cut -dC -f2 | sed "s/D/)(/g" | sed "s/*/,/g")
    sed -i "s/^$tone=.*$/$tone=|t($rewrite)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_t"
    sleep 3
    asterisk -rx "module reload"
    exit
elif [ $type == "B" ]; then
    rewrite=$(echo $1 | cut -dB -f2)
    mychar=$(cat $CWCHARS | grep $rewrite | cut -d' ' -f2)
    sed -i "s/^$tone=.*$/$tone=|m$mychar/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_t"
    sleep 3
    asterisk -rx "module reload"
    exit
elif [ $type == "A" ]; then
    rewrite=$(echo $1 | cut -s -dA -f2)
    myword=$(cat $VOCAB | grep $rewrite | cut -d' ' -f2)
    cat $VOCAB | grep $myword | cut -d' ' -f2 >$SNDCST/ct$ct.ulaw
    sed -i "s/^$tone=.*$/$tone=custom\/ct$ct/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_t"
    sleep 3
    asterisk -rx "module reload"
    exit
else
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
fi

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
