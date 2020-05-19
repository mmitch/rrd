#!/bin/bash
#
# spreads all desired scripts over a 5 minute window
#
# Copyright (C) 2007, 2008, 2011, 2013, 2015-2019  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL v3 or later.
#
# This file is part of my rrd scripts (https://github.com/mmitch/rrd).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# set this to your git checkout; either relative or absolute
SCRIPTPATH=.

#
# set sleep time in seconds between calls
# total script runtime should not exceed 5 minutes!
RRD_WAIT=${RRD_WAIT:-16}

#
# how many graphs should be rendered?
# 0 = dynamic (twice per hour = 1, otherwise = 5)
# 1 = [hour, day, week, year] every 5 minutes
# 2 =       [day, week, year] every 5 minutes
#  [...]
# 5 = none ==              [] every 5 minutes
DRAW_DETAILS=0

LANG=C
export LANG

#
# lockfile handling - ensure only one parallel run
SECONDS=0

LOCKFILE=/var/tmp/rrd_runall.lock
lockfile -r 0 -l 900 $LOCKFILE || exit

LOCKFILE_AQUISITION=$SECONDS
SECONDS=0

#
# dynamic graph details depending on time
if [ $DRAW_DETAILS -eq 0 ] ; then
    printf -v MINUTE '%(%M)T' -1
    MINUTE=$(( ${MINUTE#0} % 30 ))
    if [ $MINUTE -lt 5 ] ; then
	DRAW_DETAILS=1
    else
	DRAW_DETAILS=5
    fi
fi

#
# translate graph details to seconds for easier implementation in the scripts
case $DRAW_DETAILS in
    1) DRAW_DETAILS=3600      # hour
       ;;
    2) DRAW_DETAILS=86400     # day
       ;;
    3) DRAW_DETAILS=604800    # week
       ;;
    4) DRAW_DETAILS=31536000  # year
       ;;
    5) DRAW_DETAILS=31536001  # year + 1 -> never
       ;;
esac

#
# call the scripts and wait between calls to spread the load
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/network.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/tunnels.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/temperature.pl $DRAW_DETAILS 2> /dev/null

/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/memory.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/load.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/diskfree.pl $DRAW_DETAILS 2> /dev/null

/bin/sleep "$RRD_WAIT"
#"$SCRIPTPATH"/ups.pl $DRAW_DETAILS 2>&1 | grep -F -v 'Init SSL without certificate database'
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/cpu.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"

"$SCRIPTPATH"/io.pl $DRAW_DETAILS 2> /dev/null
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/netstat.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/unbound.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/firewall.pl $DRAW_DETAILS

/bin/sleep "$RRD_WAIT"
# "$SCRIPTPATH"/connecttime.pl $DRAW_DETAILS -- superseded by fritz.pl
"$SCRIPTPATH"/fritz.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/bogofilter.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/cpufreq.pl $DRAW_DETAILS

/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/roundtrip.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/ntpd.pl $DRAW_DETAILS
/bin/sleep "$RRD_WAIT"
"$SCRIPTPATH"/entropy.pl $DRAW_DETAILS

# remove lockfile
rm -f $LOCKFILE

LOCKFILE_HELD=$SECONDS

if [ $LOCKFILE_HELD -ge 300 ]; then

    echo This run took more than 5 minutes and will probably delay future runs.
    echo Consider reducing \$RRD_WAIT
    echo
    echo details:
    echo LOCKFILE_AQUISITION: $LOCKFILE_AQUISITION seconds
    echo LOCKFILE_HELD: $LOCKFILE_HELD seconds
    echo RRD_WAIT: "$RRD_WAIT" seconds

fi
