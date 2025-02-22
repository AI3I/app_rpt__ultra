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

idstate=$(sudo asterisk -rx "rpt xnode $MYNODE" | grep ^ider_state | cut -d'=' -f2 | cut -b1)

if [ "$SPECIALID" == "1" ]; then
    ln -fs $SNDID/special_id.ulaw $SOUNDS/voice_id.ulaw
elif [ "$SPECIALID" == "0" ]; then
    if [ "$idstate" == "0" ]; then # QUEUED IN TAIL
        ln -fs $SNDID/anxious_id.ulaw $SOUNDS/voice_id.ulaw
    elif [ "$idstate" == "1" ]; then # QUEUED IN CLEANUP
        if [ "$ROTATEPIDS" == "1" ]; then
            pidchurn=$(shuf -i1-5 -n1) # Randomize Pending IDs 1 through 5
            ln -fs $SNDID/pending_id_$pidchurn.ulaw $SOUNDS/voice_id.ulaw
        else
            ln -fs $SNDID/pending_id_$PENDINGID.ulaw $SOUNDS/voice_id.ulaw
        fi
    elif [ "$idstate" == "2" ]; then # CLEAN
        if [ "$ROTATEIIDS" == "1" ]; then
            iidchurn=$(shuf -i1-3 -n1) # Randomize Initial IDs 1 through 3
            ln -fs $SNDID/initial_id_$iidchurn.ulaw $SOUNDS/voice_id.ulaw
        else
            ln -fs $SNDID/initial_id_$INITIALID.ulaw $SOUNDS/voice_id.ulaw
        fi
    else
        exit
    fi
else
    exit
fi

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
