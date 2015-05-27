#!/bin/bash
# there sure are some bashisms here...

#
# set sleep time in seconds between calls
# total script runtime should not exceed 5 minutes!
RRD_WAIT=${RRD_WAIT:-17}

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
LOCKFILE=/var/tmp/rrd_runall.lock
lockfile -r 0 -l 900 $LOCKFILE || exit

#
# dynamic graph details depending on time
if [ $DRAW_DETAILS -eq 0 ] ; then
    printf -v MINUTE '%(%M)T' -1
    MINUTE=$(( $MINUTE % 30 ))
    if [ $MINUTE -lt 5 ] ; then
	DRAW_DETAILS=1
    else
	DRAW_DETAILS=5
    fi
fi

#
# translate graph details to seconds for easier implementation in the scripts
case DRAW_DETAILS in
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
/bin/sleep $RRD_WAIT
/home/mitch/rrd/network.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/tunnels.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/temperature.pl $DRAW_DETAILS 2> /dev/null

/bin/sleep $RRD_WAIT
/home/mitch/rrd/memory.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/load.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/diskfree.pl $DRAW_DETAILS 2> /dev/null

/bin/sleep $RRD_WAIT
#/home/mitch/rrd/ups.pl $DRAW_DETAILS 2>&1 | fgrep -v 'Init SSL without certificate database'
/bin/sleep $RRD_WAIT
/home/mitch/rrd/cpu.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT

/home/mitch/rrd/io.pl $DRAW_DETAILS 2> /dev/null
/bin/sleep $RRD_WAIT
/home/mitch/rrd/netstat.pl $DRAW_DETAILS 2>&1 | fgrep -v 'error parsing /proc/net/snmp: Success'
/bin/sleep $RRD_WAIT
/home/mitch/rrd/unbound.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/firewall.pl $DRAW_DETAILS

/bin/sleep $RRD_WAIT
# /home/mitch/rrd/connecttime.pl $DRAW_DETAILS -- superseded by fritz.pl
/home/mitch/rrd/fritz.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/bogofilter.pl $DRAW_DETAILS
/bin/sleep $RRD_WAIT
/home/mitch/rrd/cpufreq.pl $DRAW_DETAILS

/bin/sleep $RRD_WAIT
/home/mitch/rrd/roundtrip.pl $DRAW_DETAILS

# remove lockfile
rm -f $LOCKFILE
