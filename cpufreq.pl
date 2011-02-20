#!/usr/bin/perl
#
# RRD script to display cpufreq statistics
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
my $datafile = "$conf{DBPATH}/cpufreq.rrd";
my $picbase  = "$conf{OUTPATH}/cpufreq-";
my $stats = '/sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state';
my @colors = qw(
                00F0B0
                E00070
                40D030
                2020F0
                E0E000
                00FF00
                0000FF
                AAAAAA
		);

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;


# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 '--step=60',
		 'DS:state0:COUNTER:600:0:32000',
		 'DS:state1:COUNTER:600:0:32000',
		 'DS:state2:COUNTER:600:0:32000',
		 'DS:state3:COUNTER:600:0:32000',
		 'DS:state4:COUNTER:600:0:32000',
		 'DS:state5:COUNTER:600:0:32000',
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 );
      
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# get data
open STATS, '<', $stats or die "can't open `$stats': $!";
my @stats = ('U', 'U', 'U', 'U', 'U', 'U');
my @name;
while (my $line = <STATS>) {
    last if $. > 6;
    chomp $line;
    my ($name, $stat) = split /\s+/, $line;
    push @name, $name;
    $stats[$.-1] = $stat;
}
close STATS or die "can't close `$stats': $!";

# update database
RRDs::update($datafile,
	     join ':', ('N', @stats),
	     );

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};

    my (@def, @area);

    for my $i (0 .. (scalar @name - 1)) {
	push @def,  "DEF:state${i}=${datafile}:state${i}:AVERAGE";
	push @area, ($i ? 'STACK' : 'AREA') . ":state${i}#${colors[$i]}:${name[$i]}";
    }

    RRDs::graph($picbase . $scale . '.png',
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} cpu frequencies (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--upper-limit=100',
		'--lower-limit=0',
                '--rigid',
		
		@def,
		@area,
		
                'COMMENT:\n',

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
