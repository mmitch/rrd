#!/usr/bin/perl
# $Id: dnscache.pl,v 1.12 2004-11-07 23:41:49 mitch Exp $
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
my $logpath  = $conf{DNSCACHE_LOGPATH};

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 "--step=60",
		 "DS:hit:COUNTER:600:0:150000",
		 "DS:miss:COUNTER:600:0:150000",
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
my ($hits, $misses) = ('U', 'U');
my $logfile = $logpath.'/current';
open CURRENT, '<', "$logfile" or die "can't open $logfile: $!";
while (my $line = <CURRENT>) {
    chomp $line;
    my @line = split / /, $line;
    ($hits, $misses) = ($line[6], $line[7]) if $line[1] eq 'stats';
}
close CURRENT or die "can't close $logfile: $!";

# current log empty? get the last full log
if ($hits eq 'U') {
    $logfile = (sort glob $logpath.'/@*')[-1];
    open LASTLOG, '<', "$logfile" or die "can't open $logfile: $!";
    while (my $line = <LASTLOG>) {
	chomp $line;
	my @line = split / /, $line;
	($hits, $misses) = ($line[6], $line[7]) if $line[1] eq 'stats';
    }
    close LASTLOG or die "can't close $logfile: $!";
}

# update database
RRDs::update($datafile,
	     "N:$hits:$misses"
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
		"--title=${hostname} dnscache stats (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		"--lower-limit=-1",
		
		"DEF:hit=${datafile}:hit:AVERAGE",
		"DEF:miss_o=${datafile}:miss:AVERAGE",
#		"DEF:hit_max=${datafile}:hit:MAX",
#		"DEF:miss_o_max=${datafile}:miss:MAX",
		"CDEF:miss=miss_o,hit,-",
#		"CDEF:miss_max=miss_o_max,hit_max,-",
		"CDEF:total=0,hit,-,miss,-",
#		"CDEF:total_max=0,hit_max,-,miss_max,-",
		"CDEF:ratio=hit,total,/",
#		"CDEF:ratio_max=hit_max,total_max,/",
		
#		'AREA:hit_max#B0B0F0:max cache hits [1/sec]',
#		'STACK:miss_max#F0B0B0:max cache misses [1/sec]',
#		'AREA:ratio_max#B0F0B0:max cache hit ratio',
		'COMMENT:\n',
		'AREA:hit#0000D0:avg cache hits [1/sec]',
		'STACK:miss#D00000:avg cache misses [1/sec]',
		'AREA:ratio#00D000:avg cache hit ratio',
		'HRULE:0#000000',
		'HRULE:-1#000000',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
