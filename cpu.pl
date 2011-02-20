#!/usr/bin/perl
#
# RRD script to display cpu usage
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
my @datafile = ("$conf{DBPATH}/cpu0.rrd", "$conf{DBPATH}/cpu1.rrd");
my $picbase   = "$conf{OUTPATH}/cpu-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

for my $cpu ( qw(0 1) ) {

    # generate database if absent
    if ( ! -e $datafile[$cpu] ) {
	RRDs::create($datafile[$cpu],
		     "DS:user:COUNTER:600:0:101",
		     "DS:nice:COUNTER:600:0:101",
		     "DS:system:COUNTER:600:0:101",
		     "DS:idle:COUNTER:600:0:101",
		     "DS:iowait:COUNTER:600:0:101",
		     "DS:hw_irq:COUNTER:600:0:101",
		     "DS:sw_irq:COUNTER:600:0:101",
		     "RRA:AVERAGE:0.5:1:600",
		     "RRA:AVERAGE:0.5:6:700",
		     "RRA:AVERAGE:0.5:24:775",
		     "RRA:AVERAGE:0.5:288:797"
		     );
      $ERR=RRDs::error;
	  die "ERROR while creating $datafile[$cpu]: $ERR\n" if $ERR;
	  print "created $datafile[$cpu]\n";
      }

    # get cpu usage
    open PROC, "<", "/proc/stat" or die "can't open /proc/stat: $!\n";
    my $cpuline;
    while ($cpuline = <PROC>) {
	last if $cpuline =~ /^cpu$cpu /;
    }
    close PROC or die "can't close /proc/stat: $!\n";

    chomp $cpuline;
    my (undef, $user, $nice, $system, $idle, $iowait, $hw_irq, $sw_irq) = split /\s+/, $cpuline;
    $iowait = 0 unless defined $iowait;
    $hw_irq = 0 unless defined $hw_irq;
    $sw_irq = 0 unless defined $sw_irq;
    
    # update database
    RRDs::update($datafile[$cpu],
		 "N:${user}:${nice}:${system}:${idle}:${iowait}:${hw_irq}:${sw_irq}"
		 );
    $ERR=RRDs::error;
    die "ERROR while updating $datafile[$cpu]: $ERR\n" if $ERR;
    
}

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} cpu usage (last $scale)",
		'--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
                '--lower-limit=-100',
                '--upper-limit=100',
		'--rigid',

		"DEF:user0=${datafile[0]}:user:AVERAGE",
		"DEF:nice0=${datafile[0]}:nice:AVERAGE",
		"DEF:system0=${datafile[0]}:system:AVERAGE",
		"DEF:idle0=${datafile[0]}:idle:AVERAGE",
		"DEF:iowait0=${datafile[0]}:iowait:AVERAGE",
		"DEF:hw_irq0=${datafile[0]}:hw_irq:AVERAGE",
		"DEF:sw_irq0=${datafile[0]}:sw_irq:AVERAGE",

		"DEF:user1a=${datafile[1]}:user:AVERAGE",
		"DEF:nice1a=${datafile[1]}:nice:AVERAGE",
		"DEF:system1a=${datafile[1]}:system:AVERAGE",
		"DEF:idle1a=${datafile[1]}:idle:AVERAGE",
		"DEF:iowait1a=${datafile[1]}:iowait:AVERAGE",
		"DEF:hw_irq1a=${datafile[1]}:hw_irq:AVERAGE",
		"DEF:sw_irq1a=${datafile[1]}:sw_irq:AVERAGE",

		'CDEF:user1=0,user1a,-',
		'CDEF:nice1=0,nice1a,-',
		'CDEF:system1=0,system1a,-',
		'CDEF:idle1=0,idle1a,-',
		'CDEF:iowait1=0,iowait1a,-',
		'CDEF:hw_irq1=0,hw_irq1a,-',
		'CDEF:sw_irq1=0,sw_irq1a,-',

		'AREA:hw_irq0#000000:hw_irq',
		'STACK:sw_irq0#AAAAAA:sw_irq',
		'STACK:iowait0#E00070:iowait',
		'STACK:system0#2020F0:system',
		'STACK:user0#F0A000:user',
		'STACK:nice0#E0E000:nice',
		'STACK:idle0#60D050:idle',
		'AREA:hw_irq1#000000',
		'STACK:sw_irq1#AAAAAA',
		'STACK:iowait1#E00070',
		'STACK:system1#2020F0',
		'STACK:user1#F0A000',
		'STACK:nice1#E0E000',
		'STACK:idle1#60D050',
		'COMMENT:\n',
		'COMMENT: ',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile[0]/$datafile[1] $time: $ERR\n" if $ERR;
}
