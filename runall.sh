#!/bin/sh
# $Id: runall.sh,v 1.3 2007-04-05 21:43:09 mitch Exp $
WAIT=17

/bin/sleep $WAIT
/home/mitch/rrd/network.pl
/bin/sleep $WAIT
/home/mitch/rrd/tunnels.pl
/bin/sleep $WAIT
/home/mitch/rrd/temperature.pl 2> /dev/null

/bin/sleep $WAIT
/home/mitch/rrd/memory.pl
/bin/sleep $WAIT
/home/mitch/rrd/load.pl
/bin/sleep $WAIT
/home/mitch/rrd/diskfree.pl 2> /dev/null

/bin/sleep $WAIT
/home/mitch/rrd/ups.pl
/bin/sleep $WAIT
/home/mitch/rrd/cpu.pl
/bin/sleep $WAIT

/home/mitch/rrd/io.pl 2> /dev/null
/bin/sleep $WAIT
/home/mitch/rrd/netstat.pl
/bin/sleep $WAIT
/home/mitch/rrd/dnscache.pl
/bin/sleep $WAIT
/home/mitch/rrd/firewall.pl

/bin/sleep $WAIT
/home/mitch/rrd/connecttime.pl
