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

idstring=$(echo $1 | cut -c1,2)
cwmsg=/tmp/cwmsg
voicemsg=/tmp/voicemsg

case $idstring in
00) # Forced CW ID
    rewrite=$(echo $1 | cut -d'D' -f2 | sed "s/*/ /g")
    cat /dev/null >$cwmsg
    for i in $rewrite; do cat $CWCHARS | grep $i | cut -d' ' -f2 | tr -d 'n' >>$cwmsg; done
    cwid=$(cat $cwmsg)
    sed -i "s/^idtalkover=.*$/idtalkover=|i$cwid/g" $RPTCONF
    cat /dev/null >$cwmsg
    exit
    ;;
01) # Initial ID 1
    slot=$SNDID/initial_id_1.ulaw
    ;;
02) # Initial ID 2
    slot=$SNDID/initial_id_2.ulaw
    ;;
03) # Initial ID 3
    slot=$SNDID/initial_id_3.ulaw
    ;;
04) # Anxious ID
    slot=$SNDID/anxious_id.ulaw
    ;;
05) # Pending ID 1
    slot=$SNDID/pending_id_1.ulaw
    ;;
06) # Pending ID 2
    slot=$SNDID/pending_id_2.ulaw
    ;;
07) # Pending ID 3
    slot=$SNDID/pending_id_3.ulaw
    ;;
08) # Pending ID 4
    slot=$SNDID/pending_id_4.ulaw
    ;;
09) # Pending ID 5
    slot=$SNDID/pending_id_5.ulaw
    ;;
10) # Special ID
    slot=$SNDID/special_id.ulaw
    ;;
11) # Tail Message 1
    slot=$SNDTAIL/tail_message_1.ulaw
    ;;
12) # Tail Message 2
    slot=$SNDTAIL/tail_message_2.ulaw
    ;;
13) # Tail Message 3
    slot=$SNDTAIL/tail_message_3.ulaw
    ;;
14) # Tail Message 4
    slot=$SNDTAIL/tail_message_4.ulaw
    ;;
15) # Tail Message 5
    slot=$SNDTAIL/tail_message_5.ulaw
    ;;
16) # Tail Message 6
    slot=$SNDTAIL/tail_message_6.ulaw
    ;;
17) # Tail Message 7
    slot=$SNDTAIL/tail_message_7.ulaw
    ;;
18) # Tail Message 8
    slot=$SNDTAIL/tail_message_8.ulaw
    ;;
19) # Tail Message 9
    slot=$SNDTAIL/tail_message_9.ulaw
    ;;
20) # Bulletin Board Message 1
    slot=$sndmsg/bulletin_board_1.ulaw
    ;;
21) # Bulletin Board Message 2
    slot=$sndmsg/bulletin_board_2.ulaw
    ;;
22) # Bulletin Board Message 3
    slot=$sndmsg/bulletin_board_3.ulaw
    ;;
23) # Bulletin Board Message 4
    slot=$sndmsg/bulletin_board_4.ulaw
    ;;
24) # Bulletin Board Message 5
    slot=$sndmsg/bulletin_board_5.ulaw
    ;;
25) # Demonstration Message 1
    slot=$sndmsg/demonstration_1.ulaw
    ;;
26) # Demonstration Message 2
    slot=$sndmsg/demonstration_2.ulaw
    ;;
27) # Demonstration Message 3
    slot=$sndmsg/demonstration_3.ulaw
    ;;
28) # Demonstration Message 4
    slot=$sndmsg/demonstration_4.ulaw
    ;;
29) # Demonstration Message 5
    slot=$sndmsg/demonstration_5.ulaw
    ;;
30) # Emergency Auto Dial slot 0
    slot=$sndmsg/emergency_autodial_0.ulaw
    ;;
31) # Emergency Auto Dial slot 1
    slot=$sndmsg/emergency_autodial_1.ulaw
    ;;
32) # Emergency Auto Dial slot 2
    slot=$sndmsg/emergency_autodial_2.ulaw
    ;;
33) # Emergency Auto Dial slot 3
    slot=$sndmsg/emergency_autodial_3.ulaw
    ;;
34) # Emergency Auto Dial slot 4
    slot=$sndmsg/emergency_autodial_4.ulaw
    ;;
35) # Emergency Auto Dial slot 5
    slot=$sndmsg/emergency_autodial_5.ulaw
    ;;
36) # Emergency Auto Dial slot 6
    slot=$sndmsg/emergency_autodial_6.ulaw
    ;;
37) # Emergency Auto Dial slot 7
    slot=$sndmsg/emergency_autodial_7.ulaw
    ;;
38) # Emergency Auto Dial slot 8
    slot=$sndmsg/emergency_autodial_8.ulaw
    ;;
39) # Emergency Auto Dial slot 9
    slot=$sndmsg/emergency_autodial_9.ulaw
    ;;
40) # Mailbox Message slot 0
    slot=$sndmsg/mailbox_0.ulaw
    ;;
41) # Mailbox Message slot 1
    slot=$sndmsg/mailbox_1.ulaw
    ;;
42) # Mailbox Message slot 2
    slot=$sndmsg/mailbox_2.ulaw
    ;;
43) # Mailbox Message slot 3
    slot=$sndmsg/mailbox_3.ulaw
    ;;
44) # Mailbox Message slot 4
    slot=$sndmsg/mailbox_4.ulaw
    ;;
45) # Mailbox Message slot 5
    slot=$sndmsg/mailbox_5.ulaw
    ;;
46) # Mailbox Message slot 6
    slot=$sndmsg/mailbox_6.ulaw
    ;;
47) # Mailbox Message slot 7
    slot=$sndmsg/mailbox_7.ulaw
    ;;
48) # Mailbox Message slot 8
    slot=$sndmsg/mailbox_8.ulaw
    ;;
49) # Mailbox Message slot 9
    slot=$sndmsg/mailbox_9.ulaw
    ;;
50) # Long Tone Zero (LiTZ) Alert
    slot=$sndmsg/litz_alert.ulaw
    ;;
*) # Something went wrong!
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
    ;;
esac

# Write the message into the appropriate message slot
rewrite=$(echo $1 | cut -d'D' -f2 | sed "s/*/ /g")
cat /dev/null >$voicemsg
for i in $rewrite; do cat $VOCAB | grep $i | cut -d' ' -f2 >>$voicemsg; done
cat $(cat $voicemsg) >$slot
cat /dev/null >$voicemsg

# Playback an appropriate status based on the message slot being written to
if [ "$idstring" -eq "00" ]; then
    asterisk -rx "rpt localplay $MYNODE rpt/write_c_w_i_d"
    exit
elif [ "$idstring" -le "10" ]; then
    asterisk -rx "rpt localplay $MYNODE rpt/write_i_d"
    exit
elif [ "$idstring" -le "19" ]; then
    asterisk -rx "rpt localplay $MYNODE rpt/write_t_m"
    exit
elif [ "$idstring" -le "50" ]; then
    asterisk -rx "rpt localplay $MYNODE rpt/write_message"
    exit
else
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
fi
