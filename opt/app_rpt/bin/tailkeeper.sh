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

if [ "$SEVEREWEATHER" == "1" ]; then
    ln -sf $SOUNDS/$SVWXALERT.ulaw $SOUNDS/tail_message.ulaw
elif [ "$SEVEREWEATHER" == "2" ]; then
    ln -sf $SOUNDS/$RTWXALERT.ulaw $SOUNDS/tail_message.ulaw
elif [ "$SEVEREWEATHER" == "0" ] || [ "$SEVEREWEATHER" == "3" ] || [ "$SEVEREWEATHER" == "4" ]; then
    if [ "$ENABLETAIL" == "1" ] && [ "$SCHEDULER" == "1" ]; then
        if [ "$ROTATETMSG" == "0" ]; then
            if [ "$SPECIALTAIL" == "2" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$SPECIALTAILPREMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$SPECIALTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$SPECIALTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$MEETINGTAIL" == "2" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$MEETINGTAILPREMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$MEETINGTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$MEETINGTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$NETTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$NETTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            else
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/tail_message.ulaw_$TAILMSG) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/tail_message.ulaw_$TAILMSG) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/tail_message.ulaw_$TAILMSG) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/tail_message.ulaw_$TAILMSG $SOUNDS/tail_message.ulaw
                fi
            fi
        elif [ "$ROTATETMSG" == "1" ]; then
            if [ "$SPECIALTAIL" == "2" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$SPECIALTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$SPECIALTAILPREMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$SPECIALTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$SPECIALTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$SPECIALTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$MEETINGTAIL" == "2" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$MEETINGTAILPREMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$MEETINGTAILPREMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$MEETINGTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$MEETINGTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$MEETINGTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            elif [ "$NETTAIL" == "1" ]; then
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$NETTAILMSG.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/$NETTAILMSG.ulaw $SOUNDS/tail_message.ulaw
                fi
            else
                tailchurn=$(shuf -i1-9 -n1) # Randomize Tail Messages 1 through 9
                if [ "$ENABLETEMP" == "1" ] && [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/$TEMPMSG.ulaw $SOUNDS/tail_message_$tailchurn.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETEMP" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TEMPMSG.ulaw $SOUNDS/tail_message_$tailchurn.ulaw) $SOUNDS/tail_message.ulaw
                elif [ "$ENABLETIME" == "1" ]; then
                    ln -sf $(shuf -n 1 -e $SOUNDS/$TIMEMSG.ulaw $SOUNDS/tail_message_$tailchurn.ulaw) $SOUNDS/tail_message.ulaw
                else
                    ln -sf $SOUNDS/tail_message_$tailchurn.ulaw $SOUNDS/tail_message.ulaw
                fi
            fi
        else
            echo "ERROR: We couldn't figure out whether or not to rotate tail messages!"
            exit
        fi
    else
        echo "ERROR: Something is disabled, either tail messages or the scheduler."
        exit
    fi
else
    echo "ERROR: We have a problem with severe weather alerting statuses."
    exit
fi
