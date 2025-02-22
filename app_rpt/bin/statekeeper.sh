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

case $1 in
default) # Reset to Default Operations
    sed -i "s/^SCHEDULER=.*$/SCHEDULER=1/g" $sourcefile
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
    sed -i "s/^ENABLETEMP=0/ENABLETEMP=1/g" $sourcefile
    sed -i "s/^ENABLETIME=0/ENABLETIME=1/g" $sourcefile
    sed -i "s/^;idrecording=.*$/idrecording=voice_id/g" $RPTCONF
    sed -i "s/^idrecording=.*$/idrecording=voice_id/g" $RPTCONF
    sed -i "s/^;tailmessagetime=/tailmessagetime=$TMTIMEL/g" $RPTCONF
    sed -i "s/^;tailmessagelist=/tailmessagelist=none/g" $RPTCONF
    sed -i "s/^nounkeyct=.*$/nounkeyct=0/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSDEF"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 33 $MYNODE" # Set Local Telemetry to ENABLED
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 38 $MYNODE" # Set Foreign Link Local Output to FOLLOW LOCAL TELEMETRY
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 42 $MYNODE" # Set EchoLink to ANNOUNCE NODE NUMBER ONLY
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 45 $MYNODE" # Set Link Activity Timer to ENABLED
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 15 $MYNODE" # Set Scheduler to ENABLED
    sleep 15
    asterisk -rx "module reload"
    ;;
standard) # Standard Operations
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSSTD"
    sleep 15
    asterisk -rx "module reload"
    ;;
litzalert) # Long Tone Zero (LiTZ) Alert
    asterisk -rx "rpt fun $MYNODE *894#"
    sleep 5
    asterisk -rx "rpt localplay $MYNODE rpt/litz_alert"
    sleep 20
    asterisk -rx "rpt fun $MYNODE *894#"
    sleep 5
    asterisk -rx "rpt localplay $MYNODE rpt/litz_alert"
    ;;
severeweather) # Severe Weather Alert
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMES/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTSWX/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTSWX/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTSWX/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(660,880,100,4096)/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(660,880,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSSWX"
    sleep 15
    asterisk -rx "module reload"
    sleep 3
    asterisk -rx "rpt fun $MYNODE *895#"
    sleep 6
    asterisk -rx "rpt cmd $MYNODE cop 48 !1051/5000"
    sleep 7
    asterisk -rx "rpt localplay $MYNODE rpt/severe_weather_alert"
    ;;
weatheralert) # Weather Alert
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEM/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTWXA/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTWXA/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTWXA/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "module reload"
    ;;
tactical) # Tactical Operations
    sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" $sourcefile
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTTAC/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTTAC/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTTAC/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSTAC"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 16 $MYNODE" # Set Scheduler to DISABLED
    sleep 15
    asterisk -rx "module reload"
    ;;
stealth) # Stealth Operations
    sed -i "s/^SCHEDULER=.*$/SCHEDULER=0/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" $sourcefile
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" $RPTCONF
    sed -i "s/^idrecording=/;idrecording=/g" $RPTCONF
    sed -i "s/^tailmessagetime=/;tailmessagetime=/g" $RPTCONF
    sed -i "s/^tailmessagelist=/;tailmessagelist=/g" $RPTCONF
    sed -i "s/^nounkeyct=.*$/nounkeyct=1/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTSTL/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTSTL/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTSTL/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(0,0,50,0)/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(0,0,50,0)/g" $RPTCONF
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSSTL"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 18 $MYNODE" # Set User Functions to DISABLED
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 34 $MYNODE" # Set Local Telemetry to DISABLED
    sleep 15
    asterisk -rx "module reload"
    ;;
daytime) # Daytime Operations
    sed -i "s/^SCHEDULER=.*$/SCHEDULER=1/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSDAY"
    sleep 15
    asterisk -rx "module reload"
    ;;
nighttime) # Nighttime Operations
    sed -i "s/^SCHEDULER=.*$/SCHEDULER=1/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" $sourcefile
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSNGT"
    sleep 15
    asterisk -rx "module reload"
    ;;
net) # Net
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" $sourcefile
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" $sourcefile
    sed -i "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" $RPTCONF
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTNET/g" $RPTCONF
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTNET/g" $RPTCONF
    sed -i "s/^remotect=.*$/remotect=$CTNET/g" $RPTCONF
    sed -i "s/^remotemon=.*$/remotemon=|mN/g" $RPTCONF
    sed -i "s/^remotetx=.*$/remotetx=|mN/g" $RPTCONF
    asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    asterisk -rx "rpt cmd $MYNODE cop 14 $SSNET"
    sleep 15
    asterisk -rx "module reload"
    ;;
clock) # Grandfather Clock
    asterisk -rx "rpt cmd $MYNODE cop 48 !830 827/450,!0/250,!659 656/450,!0/250,!739 736/450,!0/250,!493 490/450,!0/750,!493 490/450,!0/250,!739 736/450,!0/250,!830 827/450,!0/250,!659 656/450"
    sleep 2
    asterisk -rx "rpt localplay $MYNODE rpt/current_time"
    ;;
*) # Error
    asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit
    ;;
esac

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
