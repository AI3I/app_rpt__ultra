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

hours=$(date +%k)
minutes=$(date +%M)

if perl -e 'exit ((localtime)[8])'; then
    if [ $hours -ge '17' -a $hours -le '23' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good evening! The time is <time> P.M.
        cat $SNDFEMALE/good_evening.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/p_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '12' -a $hours -lt '17' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good afternoon! The time is <time> P.M.
        cat $SNDFEMALE/good_afternoon.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/p_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '6' -a $hours -lt '12' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good morning! The time is <time> A.M.
        cat $SNDFEMALE/good_morning.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/a_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '0' -a $hours -lt '6' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good morning! The time is <time> A.M. ...why are you up?
        cat $SNDFEMALE/good_morning.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/a_m.ulaw $SNDFEMALE/pause.ulaw $SNDTAIL/why_are_you_up.ulaw >$SNDRPT/current_time.ulaw
        exit
    else
        exit
    fi
else
    if [ $hours -ge '18' -a $hours -le '23' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good evening! The time is <time> P.M.
        cat $SNDFEMALE/good_evening.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/p_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '12' -a $hours -lt '18' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good afternoon! The time is <time> P.M.
        cat $SNDFEMALE/good_afternoon.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/p_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '6' -a $hours -lt '12' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good morning! The time is <time> A.M.
        cat $SNDFEMALE/good_morning.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/a_m.ulaw >$SNDRPT/current_time.ulaw
        exit
    elif [ $hours -ge '0' -a $hours -lt '6' ]; then
        newhour=$(date +%l | tr -d ' ')
        # Good morning! The time is <time> A.M. ...why are you up?
        cat $SNDFEMALE/good_morning.ulaw $SNDFEMALE/pause.ulaw $SNDFEMALE/the_time_is.ulaw $SNDFEMALE/$newhour.ulaw $SNDFEMALE/$minutes.ulaw $SNDFEMALE/a_m.ulaw $SNDFEMALE/pause.ulaw $SNDTAIL/why_are_you_up.ulaw >$SNDRPT/current_time.ulaw
        exit
    else
        exit
    fi
fi

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
