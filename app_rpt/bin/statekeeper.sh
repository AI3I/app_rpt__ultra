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

source "%%BASEDIR%%/bin/common.sh"
sourcefile="$CONFIG_FILE"

# Validate input argument
readonly VALID_MODES="default standard litzalert severeweather weatheralert tactical stealth daytime nighttime net clock"
if [[ -z "${1:-}" ]]; then
    die_with_error "No mode specified. Valid modes: $VALID_MODES"
fi

case "$1" in
default) # Reset to Default Operations
    sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=1/g" "$sourcefile"
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
    sed -i "s/^ENABLETEMP=0/ENABLETEMP=1/g" "$sourcefile"
    sed -i "s/^ENABLETIME=0/ENABLETIME=1/g" "$sourcefile"
    sed -i.bkp "s/^;idrecording=.*$/idrecording=voice_id/g" "$RPTCONF"
    sed -i "s/^idrecording=.*$/idrecording=voice_id/g" "$RPTCONF"
    sed -i "s/^;tailmessagetime=/tailmessagetime=$TMTIMEL/g" "$RPTCONF"
    sed -i "s/^;tailmessagelist=/tailmessagelist=none/g" "$RPTCONF"
    sed -i "s/^nounkeyct=.*$/nounkeyct=0/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSDEF"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 33 $MYNODE" # Set Local Telemetry to ENABLED
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 38 $MYNODE" # Set Foreign Link Local Output to FOLLOW LOCAL TELEMETRY
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 42 $MYNODE" # Set EchoLink to ANNOUNCE NODE NUMBER ONLY
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 45 $MYNODE" # Set Link Activity Timer to ENABLED
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 15 $MYNODE" # Set Scheduler to ENABLED
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
standard) # Standard Operations
    sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSSTD"
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
litzalert) # Long Tone Zero (LiTZ) Alert
    sudo asterisk -rx "rpt fun $MYNODE *8404#"
    sleep 5
    sudo asterisk -rx "rpt localplay $MYNODE rpt/litz_alert"
    sleep 20
    sudo asterisk -rx "rpt fun $MYNODE *8404#"
    sleep 5
    sudo asterisk -rx "rpt localplay $MYNODE rpt/litz_alert"
    ;;
severeweather) # Severe Weather Alert
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMES/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTSWX/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTSWX/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTSWX/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(660,880,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(660,880,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSSWX"
    sleep 15
    sudo asterisk -rx "module reload"
    sleep 3
    sudo asterisk -rx "rpt fun $MYNODE *8405#"
    sleep 6
    sudo asterisk -rx "rpt cmd $MYNODE cop 48 !1051/5000"
    sleep 7
    sudo asterisk -rx "rpt localplay $MYNODE rpt/severe_weather_alert"
    ;;
weatheralert) # Weather Alert
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEM/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTWXA/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTWXA/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTWXA/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "module reload"
    ;;
tactical) # Tactical Operations
    sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=0/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTTAC/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTTAC/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTTAC/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSTAC"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 16 $MYNODE" # Set Scheduler to DISABLED
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
stealth) # Stealth Operations
    sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=0/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" "$RPTCONF"
    sed -i "s/^idrecording=/;idrecording=/g" "$RPTCONF"
    sed -i "s/^tailmessagetime=/;tailmessagetime=/g" "$RPTCONF"
    sed -i "s/^tailmessagelist=/;tailmessagelist=/g" "$RPTCONF"
    sed -i "s/^nounkeyct=.*$/nounkeyct=1/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTSTL/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTSTL/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTSTL/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(0,0,50,0)/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(0,0,50,0)/g" "$RPTCONF"
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSSTL"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 18 $MYNODE" # Set User Functions to DISABLED
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 34 $MYNODE" # Set Local Telemetry to DISABLED
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
daytime) # Daytime Operations
    sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=1/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSDAY"
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
nighttime) # Nighttime Operations
    sed -i.bkp "s/^SCHEDULER=.*$/SCHEDULER=1/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=0/g" "$sourcefile"
    sed -i "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=3/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEL/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTUNL/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTRMT/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTUNK/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|t(350,440,100,4096)/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|t(480,620,100,4096)/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSNGT"
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
net) # Net
    sed -i.bkp "s/^SEVEREWEATHER=.*$/SEVEREWEATHER=4/g" "$sourcefile"
    sed -i "s/^SPECIALID=.*$/SPECIALID=1/g" "$sourcefile"
    sed -i.bkp "s/^tailmessagetime=.*$/tailmessagetime=$TMTIMEX/g" "$RPTCONF"
    sed -i "s/^unlinkedct=.*$/unlinkedct=$CTNET/g" "$RPTCONF"
    sed -i "s/^linkunkeyct=.*$/linkunkeyct=$CTNET/g" "$RPTCONF"
    sed -i "s/^remotect=.*$/remotect=$CTNET/g" "$RPTCONF"
    sed -i "s/^remotemon=.*$/remotemon=|mN/g" "$RPTCONF"
    sed -i "s/^remotetx=.*$/remotetx=|mN/g" "$RPTCONF"
    sudo asterisk -rx "rpt localplay $MYNODE rpt/change_over"
    sleep 3
    sudo asterisk -rx "rpt cmd $MYNODE cop 14 $SSNET"
    sleep 15
    sudo asterisk -rx "module reload"
    ;;
clock) # Grandfather Clock
    sudo asterisk -rx "rpt cmd $MYNODE cop 48 !830+829/450,!0/250,!659+658/450,!0/250,!739+738/450,!0/250,!493+492/450,!0/750,!493+492/450,!0/250,!739+738/450,!0/250,!830+829/450,!0/250,!659+658/450"
    sleep 2
    sudo asterisk -rx "rpt localplay $MYNODE rpt/current_time"
    ;;
*) # Error
    echo "ERROR: Invalid mode '$1'. Valid modes: $VALID_MODES" >&2
    sudo asterisk -rx "rpt localplay $MYNODE rpt/program_error"
    exit 1
    ;;
esac

###VERSION=2.0.2
