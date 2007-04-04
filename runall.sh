#!/bin/sh
# $Id: runall.sh,v 1.2 2007-04-04 21:56:12 mitch Exp $
WAIT=20

/bin/sleep $WAIT
/home/mitch/rrd/network.pl && /home/mitch/rrd/tunnels.pl
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
/bin/skeep $WAIT
/home/mitch/rrd/connecttime.pl
