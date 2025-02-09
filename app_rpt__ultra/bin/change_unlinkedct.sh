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

#    PURPOSE:  Allow changing 'unlinkedct' by specifying courtesy tone from
#    table of courtesy tones defined in rpt.conf (template: 00-99) and
#    announce change locally.
sed -i "s/^unlinkedct=ct.*$/unlinkedct=ct$1/g" $RPTCONF
asterisk -rx "rpt localplay $MYNODE rpt/change_c_t"
sleep 4
asterisk -rx "module reload"
