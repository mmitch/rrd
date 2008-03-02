#!/bin/sh
RRD_WAIT=${RRD_WAIT:-17}
LANG=C

/bin/sleep $RRD_WAIT
/home/mitch/rrd/network.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/tunnels.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/temperature.pl 2> /dev/null

/bin/sleep $RRD_WAIT
/home/mitch/rrd/memory.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/load.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/diskfree.pl 2> /dev/null

/bin/sleep $RRD_WAIT
/home/mitch/rrd/ups.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/cpu.pl
/bin/sleep $RRD_WAIT

/home/mitch/rrd/io.pl 2> /dev/null
/bin/sleep $RRD_WAIT
/home/mitch/rrd/netstat.pl 2>&1 | fgrep -v 'error parsing /proc/net/snmp: Success'
/bin/sleep $RRD_WAIT
/home/mitch/rrd/dnscache.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/firewall.pl

/bin/sleep $RRD_WAIT
/home/mitch/rrd/connecttime.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/bogofilter.pl
/bin/sleep $RRD_WAIT
/home/mitch/rrd/cpufreq.pl

/bin/sleep $RRD_WAIT
/home/mitch/rrd/roundtrip.pl
