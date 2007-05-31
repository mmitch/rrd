#!/bin/sh
DATAFILE=/home/mitch/rrd/bogofilter.rrd
LINE=$(grep ^X-Bogosity: | head -n 1)
[ "$LINE" ] || exit
case ${LINE:12} in
	Ham*)
		rrdtool update $DATAFILE N:1:0:0
		;;
	Unsure*)
		rrdtool update $DATAFILE N:0:1:0
		;;
	Spam*)
		rrdtool update $DATAFILE N:0:0:1
		;;
esac
sleep 1
