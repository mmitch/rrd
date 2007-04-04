#!/usr/bin/perl
# $Id: netstat.pl,v 1.5 2007-04-04 22:02:20 mitch Exp $
#
# RRD script to display io stats
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/netstat.rrd";
my $picbase  = "$conf{OUTPATH}/netstat-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 "DS:active:COUNTER:600:0:50000",
		 "DS:passive:COUNTER:600:0:50000",
		 "DS:failed:COUNTER:600:0:50000",
		 "DS:resets:COUNTER:600:0:50000",
		 "DS:established:COUNTER:600:0:50000",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get netstats
open NETSTAT, "netstat -s|" or die "can't open `netstat -s|': $!\n";
my $string='N';
while (my $line = <NETSTAT>) {
    if ($line =~ /(\d+) active connection/) {
	$string.=":$1";
	last;
    }
}
while (my $line = <NETSTAT>) {
    if ($line =~ /(\d+) passive connection/) {
	$string.=":$1";
	last;
    }
}
while (my $line = <NETSTAT>) {
    if ($line =~ /(\d+) failed connection/) {
	$string.=":$1";
	last;
    }
}
while (my $line = <NETSTAT>) {
    if ($line =~ /(\d+) connection reset/) {
	$string.=":$1";
	last;
    }
}
while (my $line = <NETSTAT>) {
    if ($line =~ /(\d+) connections established/) {
	$string.=":$1";
	last;
    }
}
close NETSTAT or die "can't close `netstat -s|': $!\n";


# update database
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} TCP connections (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--slope-mode',

                "DEF:active=${datafile}:active:AVERAGE",
                "DEF:passive=${datafile}:passive:AVERAGE",
                "DEF:failed=${datafile}:failed:AVERAGE",
                "DEF:resets=${datafile}:resets:AVERAGE",
                "DEF:established=${datafile}:established:AVERAGE",

                'LINE1:active#7000E0:active',
                'LINE1:passive#60D050:passive',
                'LINE1:failed#E0E000:failed',
                'LINE1:resets#F0A000:resets',
                'LINE1:established#E00070:established'
                );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
