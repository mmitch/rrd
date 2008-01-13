#!/bin/sh
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
/bin/sleep $WAIT
/home/mitch/rrd/bogofilter.pl
/bin/sleep $WAIT
/home/mitch/rrd/cpufreq.pl

/bin/sleep $WAIT
/home/mitch/rrd/roundtrip.pl
