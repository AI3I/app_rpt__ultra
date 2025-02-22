case $1 in
lan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show $landevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
wlan)
    asterisk -rx "rpt localplay $MYNODE rpt/lan_ip_address"
    ip=$(ip addr show $wlandevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
vpn)
    asterisk -rx "rpt localplay $MYNODE rpt/vpn_ip_address"
    ip=$(ip addr show $vpndevice | awk '/inet / {print $2}' | awk 'BEGIN { FS = "/"}  {print $1}')
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
wan)
    ip=$(asl-node-lookup $MYNODE | tr -s ' ' | grep ^\ IP= | cut -d'=' -f2)
    asterisk -rx "rpt localplay $MYNODE rpt/wan_ip_address"
    sleep 3
    if [ -z $ip ]; then
        asterisk -rx "rpt localplay $MYNODE rpt/empty"
        exit
    else
        $BINDIR/speaktext.sh $ip
        exit
    fi
    ;;
*) ;;
esac

###EDIT: Sat Feb 22 10:02:32 AM EST 2025
