#!/usr/bin/perl
# $Id: dnscache.pl,v 1.8 2004-07-10 18:38:41 mitch Exp $
#
# RRD script to display dnscache statistics
# 2004 (c) by Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/dnscache.rrd";
my $picbase  = "$conf{OUTPATH}/dnscache-";
my $logfile  = $conf{DNSCACHE_LOG};

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 "--step=60",
		 "DS:hit:COUNTER:600:0:U",
		 "DS:miss:COUNTER:600:0:U",
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 'RRA:MAX:0.5:1:600',
		 'RRA:MAX:0.5:6:700',
		 'RRA:MAX:0.5:24:775',
		 'RRA:MAX:0.5:288:797'
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# get traffic data (only open NETDEV once)
open CURRENT, '<', $logfile or die "can't open $logfile: $!";
my ($hits, $misses);
while (my $line = <CURRENT>) {
    chomp $line;
    my @line = split / /, $line;
    ($hits, $misses) = ($line[6], $line[7]) if $line[1] eq 'stats';
}
close CURRENT or die "can't close $logfile: $!";

# update database
if ( defined $hits and defined $misses ) {
    RRDs::update($datafile,
		 "N:$hits:$misses"
		 );
  } else {
      RRDs::update($datafile,
		   'N:U:U'
		   );
    }
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} dnscache stats (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		
		"DEF:hit=${datafile}:hit:AVERAGE",
		"DEF:miss=${datafile}:miss:AVERAGE",
		"DEF:hit_max=${datafile}:hit:MAX",
		"DEF:miss_max=${datafile}:miss:MAX",
		
#		'AREA:miss',
#		'STACK:miss_max#B0B0F0',
#		'AREA:hit',
#		'STACK:hit_max#B0F0B0',
		'LINE1:miss#0000D0:cache misses [1/sec]',
		'LINE1:hit#00D000:cache hits [1/sec]',
		'COMMENT:\n',
		'COMMENT: ',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
