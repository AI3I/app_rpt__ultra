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

#    PURPOSE:  Ability to generate courtesy tones from CLI or DTMF dynamically without having to directly edit files.
#
#    CW ID:  00 D <CW character> * <CW character> * <CW character>                      ... uses characters.txt (2 digits)
#    USAGE:  <MSG slot> D <vocabulary word> * <vocabulary word> * <vocabulary word>     ... uses vocabulary.txt (3 digits) (vocabulary.txt)
#           ...'D' is a delimiter from the CW ID or message slot
#           ...'*' is a delimiter between characters or words

idstring=$(echo $1 | cut -c1,2)
cwmsg=/tmp/cwmsg
voicemsg=/tmp/voicemsg

if [ "$idstring" -eq "00" ]; then
    rewrite=$(echo $1 | cut -d'D' -f2 | sed "s/*/ /g")
    cat /dev/null >$cwmsg
    for i in $rewrite; do cat $CWCHARS | grep $i | cut -d' ' -f2 | tr -d '\n' >>$cwmsg; done
    cwid=$(cat $cwmsg)
    sed -i "s/^idtalkover=.*$/idtalkover=|i$cwid/g" $RPTCONF
    cat /dev/null >$cwmsg
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_w_i_d"
    exit
else
    msgid=$(grep ^$idstring $MSGTBL | cut -d' ' -f2)
    cat /dev/null >$voicemsg
    for i in $rewrite; do cat $VOCAB | grep $i | cut -d' ' -f2 >>$voicemsg; done
    cat $(cat $voicemsg) >$SOUNDS/$msgid.ulaw
    cat /dev/null >$voicemsg
    if [ "$idstring" -le "10" ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_i_d"
        sleep 1
        $BINDIR/speaktext.sh $idstring
        exit
    elif [ "$idstring" -le "19" ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_t_m"
        sleep 1
        $BINDIR/speaktext.sh $idstring
        exit
    elif [ "$idstring" -le "50" ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/write_message"
        sleep 1
        $BINDIR/speaktext.sh $idstring
        exit
    else
        asterisk -rx "rpt localplay $MYNODE rpt/program_error"
        exit
    fi
fi
