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

#    Adapted from works provided by AllStarLink

USBROOT=/sys/bus/usb/devices

ls $USBROOT | while read DEV; do
    USBDEV="$USBROOT/$DEV"

    IDVEND=$(cat $USBDEV/idVendor 2>/dev/null)
    case "$IDVEND" in
    "0d8c") # C108_VENDOR_ID
        IDPROD=$(cat $USBDEV/idProduct 2>/dev/null)
        if [ $((16#$IDPROD & 16#fffc)) -eq $((16#000c)) ]; then # C108_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#0012)) ]; then # C108B_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#013c)) ]; then # C108AH_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#013a)) ]; then # C119A_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#0013)) ]; then # C119B_PRODUCT_ID
            :
        elif [ $((16#$IDPROD & 16#ff00)) -eq $((16#6a00)) ]; then # N1KDO_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#0008)) ]; then # C119_PRODUCT_ID
            :
        elif [ $((16#$IDPROD)) -eq $((16#0014)) ]; then # Y-247A_PRODUCT_ID
            :
        else
            continue
        fi

        MANF=$(cat $USBDEV/manufacturer 2>/dev/null)
        if [ -n "$MANF" ]; then
            PROD="$MANF"
        else
            PROD=$(cat $USBDEV/product 2>/dev/null)
        fi
        ;;
    *)
        continue
        ;;
    esac

    for SUBDEV in $( (
        cd $USBROOT
        ls -d ${DEV}*
    )); do
        USBSUBDEV="$USBDEV/$SUBDEV"
        if [ -d $USBSUBDEV/sound ]; then
            CHANUSB=$SUBDEV
            printf "%s\t-->\t%s:%s %s\n" $CHANUSB $IDVEND $IDPROD "$PROD"
        fi
    done
done
