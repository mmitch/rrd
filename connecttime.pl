#!/usr/bin/perl
# $Id: connecttime.pl,v 1.4 2007-04-05 17:19:24 mitch Exp $
#
# RRD script to display io stats
# 2007 (c) by Christian Garbs <mitch@cgarbs.de>
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

# set variables
my $datafile = "$conf{DBPATH}/connecttime.rrd";
my $picbase  = "$conf{OUTPATH}/connecttime-";
my $onlinefile = "/var/lock/online";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 "DS:connecttime:GAUGE:600:0:700000",
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

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} ppp status (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",

                "DEF:seconds=${datafile}:connecttime:AVERAGE",
		'CDEF:hours=seconds,3600,/',

                'AREA:hours#00D000:connection time [h]',
		'COMMENT:\n',
		'COMMENT:\n',
                );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
