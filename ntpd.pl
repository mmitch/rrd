#!/usr/bin/perl
#
# RRD script to display ntpd statsistics using ntpq
# 2017 (c) by Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/ntpd.rrd";
my $picbase = "$conf{OUTPATH}/ntpd-peers-";
my $picbase2 = "$conf{OUTPATH}/ntpd-stats-";

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
if (! -e $datafile ) {
    RRDs::create($datafile,
		 'DS:outlyers:GAUGE:600:0:32',               # max 32 peers
		 'DS:candidates:GAUGE:600:0:32',             # max 32 peers
		 'DS:selected:GAUGE:600:0:32',               # max 32 peers
		 'DS:sel_delay:GAUGE:600:-1024000:1024000',  # max ~15m delay
		 'DS:sel_offset:GAUGE:600:-1024000:1024000', # max ~15m offset
		 'DS:sel_jitter:GAUGE:600:-1000:1000',       # max 1s jitter
		 'DS:sys_offset:GAUGE:600:-1024000:1024000', # max ~15m offset
		 'DS:sys_jitter:GAUGE:600:-1000:1000',       # max 1s sys jitter
		 'DS:clk_jitter:GAUGE:600:-1000:1000',       # max 1s clk jitter
		 'DS:clk_wander:GAUGE:600:-1000:1000',       # max 1s clock wander
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 'RRA:MAX:0.5:1:600',
		 'RRA:MAX:0.5:6:700',
		 'RRA:MAX:0.5:24:775',
		 'RRA:MAX:0.5:288:797',
		 'RRA:MIN:0.5:1:600',
		 'RRA:MIN:0.5:6:700',
		 'RRA:MIN:0.5:24:775',
		 'RRA:MIN:0.5:288:797'
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# gather data
my ($candidates, $selected, $outlyers) = (0, 0, 0);
my ($sel_delay, $sel_offset, $sel_jitter) = ('U', 'U', 'U');

open NTPQ, '-|', 'ntpq -p' or die $!;
while (my $line = <NTPQ>) {
    if ($line =~ /^\+/) {
	$candidates++;
    }
    elsif ($line =~ /^-/) {
	$outlyers++;
    }
    elsif ($line =~ /^\*/) {
	$selected++;
	if ($line =~ /\s(-?\d+\.\d{3})\s+(-?\d+\.\d{3})\s+(-?\d+\.\d{3})$/) {
	    ($sel_delay, $sel_offset, $sel_jitter) = ($1, $2, $3);
	}
    }
}
close NTPQ or die $!;

my ($sys_jitter, $sys_offset, $clk_jitter, $clk_wander) = (0, 0, 0, 0);

open NTPQ, '-|', 'ntpq -c rv' or die $!;
while (my $line = <NTPQ>) {
    if ($line =~ /sys_jitter=(-?\d+\.\d+)/) {
	$sys_jitter = $1;
    }
    if ($line =~ /offset=(-?\d+\.\d+)/) {
	$sys_offset = $1;
    }
    if ($line =~ /clk_jitter=(-?\d+\.\d+)/) {
	$clk_jitter = $1;
    }
    if ($line =~ /clk_wander=(-?\d+\.\d+)/) {
	$clk_wander = $1;
    }
}
close NTPQ or die $!;

# update database
RRDs::update($datafile,
             "N:$outlyers:$candidates:$selected:$sel_delay:$sel_offset:$sel_jitter:$sys_jitter:$sys_offset:$clk_jitter:$clk_wander"
    );

die "ERROR while adding $datafile: $ERR\n" if $ERR;

# draw pictures (peer counts)
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} NTP peer count (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--lower-limit=0',

                "DEF:outlyers=${datafile}:outlyers:AVERAGE",
                "DEF:candidates=${datafile}:candidates:AVERAGE",
                "DEF:selected=${datafile}:selected:AVERAGE",

                'AREA:selected#00D000:selected peer',
                'STACK:candidates#D0D000:candidates',
                'STACK:outlyers#D00000:outlyers',
		'COMMENT:\n',
		'COMMENT:\n',
                );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

# draw pictures (timings)
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase2 . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} NTP timings (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		
		"DEF:sys_offset_min=${datafile}:sys_offset:MIN",
		"DEF:sys_offset_max=${datafile}:sys_offset:MAX",
		
		"DEF:sel_delay=${datafile}:sel_delay:AVERAGE",
		"DEF:sel_offset=${datafile}:sel_offset:AVERAGE",
		"DEF:sel_jitter=${datafile}:sel_jitter:AVERAGE",
		"DEF:sys_jitter=${datafile}:sys_jitter:AVERAGE",
		"DEF:clk_jitter=${datafile}:clk_jitter:AVERAGE",
		"DEF:clk_wander=${datafile}:clk_wander:AVERAGE",
		"DEF:sys_offset=${datafile}:sys_offset:AVERAGE",

		'CDEF:sys_offset_stack=sys_offset_max,sys_offset_min,-',

		'HRULE:0#80808080',
		'LINE:sys_offset_min',
		'AREA:sys_offset_stack#F0808080::STACK',

#		'LINE1:sel_delay#F0F040:sel_delay [ms]',
		'LINE1:sel_offset#00F0F0:sel_offset [ms]',
		'LINE1:sel_jitter#F000F0:sel_jitter [ms]',
		'LINE1:sys_jitter#0000F0:sys_jitter [ms]',
		'LINE1:clk_jitter#000000:clk_jitter [ms]',
		'LINE1:clk_wander#AAAAAA:clk_wander [ms]',
		'LINE2:sys_offset#F00000:sys_offset [ms]',
		'COMMENT:\n',
	);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

