#!/usr/bin/perl
#
# RRD script to display io stats
# Copyright (C) 2007, 2011, 2015  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/connecttime.rrd";
my $picbase  = "$conf{OUTPATH}/connecttime-";
my $onlinefile = "/var/lock/online";

# global error variable
my $ERR;

# get graph minimum time ($DETAIL_TIME in rrd_runall.sh)
my $MINTIME = 1;
if (defined $ARGV[0])
{
    $MINTIME = shift @ARGV;
}

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 "DS:connecttime:GAUGE:600:0:100000",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get time of last connect
my $connecttime = 0;
if ( -e $onlinefile ) {
    $connecttime = time() - (stat(_))[9];
}

# update database
RRDs::update($datafile,
             "N:$connecttime"
             );

die "ERROR while adding $datafile $connecttime: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} time since last connect/IP change (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',

                "DEF:seconds=${datafile}:connecttime:AVERAGE",
		"DEF:oldseconds=${datafile}:connecttime:AVERAGE:end=now-${time}s:start=end-${time}s",

		"SHIFT:oldseconds:$time",
		'CDEF:hours=seconds,3600,/',
		'CDEF:oldhours=oldseconds,3600,/',

                'AREA:hours#00D000:connection time [h]',
                "LINE:oldhours#D0D0D0:connection time [h] previous $scale",
                );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
