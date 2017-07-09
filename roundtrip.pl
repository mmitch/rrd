#!/usr/bin/perl
#
# RRD script to display disk usage
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
my $datafile = "$conf{DBPATH}/roundtrip.rrd";
my $picbase  = "$conf{OUTPATH}/roundtrip-";

# watch these paths
my @hosts = @{$conf{'ROUNDTRIP_HOSTS'}};
# @hosts = grep { $_ ne '' } @hosts;
my @time;

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
		 'DS:rtt00:GAUGE:600:-1:10',
		 'DS:rtt01:GAUGE:600:-1:10',
		 'DS:rtt02:GAUGE:600:-1:10',
		 'DS:rtt03:GAUGE:600:-1:10',
		 'DS:rtt04:GAUGE:600:-1:10',
		 'DS:rtt05:GAUGE:600:-1:10',
		 'DS:rtt06:GAUGE:600:-1:10',
		 'DS:rtt07:GAUGE:600:-1:10',
		 'DS:rtt08:GAUGE:600:-1:10',
		 'DS:rtt09:GAUGE:600:-1:10',
		 'DS:rtt10:GAUGE:600:-1:10',
		 'DS:rtt11:GAUGE:600:-1:10',
		 'DS:rtt12:GAUGE:600:-1:10',
		 'DS:rtt13:GAUGE:600:-1:10',
		 'DS:rtt14:GAUGE:600:-1:10',
		 'DS:rtt15:GAUGE:600:-1:10',
		 'DS:rtt16:GAUGE:600:-1:10',
		 'DS:rtt17:GAUGE:600:-1:10',
		 'DS:rtt18:GAUGE:600:-1:10',
		 'DS:rtt19:GAUGE:600:-1:10',
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797'
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# build reverse lookup hash and initialize array
my %host;
for my $idx ( 0..19 ) {
    $host{ $hosts[$idx] } = $idx;
    $time[ $idx ] = 'U';
}

# parse roundtrip
open DF, "$conf{ROUNDTRIP_BIN}|" or die "can't open $conf{ROUNDTRIP_BIN}: $!";
while ( my $line = <DF> ) {
    chomp $line;
    my ($host, $time) = split /\s+/, $line;
    $host =~ s/\s+$//;
    $time = 'U' if $time eq '-1';
    $time[ $host{ $host } ] = $time if ( exists $host{ $host } );
}
close DF or die "can't close $conf{ROUNDTRIP_BIN}: $!";

# update database
my $string='N';
for my $idx ( 0..19 ) {
    $string .= ':' . ( $time[$idx] );
}
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# set up colorspace
my $drawn = 0;
my @colors = qw(
		00F0F0
		F0F040
		F000F0
		00F000
		0000F0
		000000
		AAAAAA
		F00000
		F09000
		C0C0C0
		009000
		FF0000
		000090
		900090
		009090
		909000
		E00070
		2020F0
		FF00FF
		20FF20
	       );

# draw which values?
my (@def, @line, @gprint);
my $first = 1;
for my $idx ( 0..19 ) {
    if ( $hosts[$idx] ne '' ) {
	my $color = $colors[$drawn];
	push @def, sprintf 'DEF:rtt%02d=%s:rtt%02d:AVERAGE', $idx, $datafile, $idx;
	push @def, sprintf 'CDEF:slow%02d=rtt%02d,0.4,GE,1,rtt%02d,UN,-,*', $idx, $idx, $idx;
	push @def, sprintf 'CDEF:on%02d=rtt%02d,0.4,LT,1,rtt%02d,UN,-,*', $idx, $idx, $idx;
	push @def, sprintf 'CDEF:off%02d=rtt%02d,UN', $idx, $idx;
	push @line, sprintf '%s:on%02d#%sff:%s', $first ? ($first=0, 'AREA')[1] : 'STACK', $idx, $color, $hosts[$idx];
	push @line, sprintf 'STACK:slow%02d#%s80', $idx, $color;
	push @line, sprintf 'STACK:off%02d#%s12', $idx, $color;
	$drawn ++;
	push @gprint, sprintf 'GPRINT:rtt%02d:AVERAGE:%%5.3lf', $idx;
	push @gprint, sprintf 'GPRINT:rtt%02d:MIN:%%5.3lf', $idx;
	push @gprint, sprintf 'GPRINT:rtt%02d:MAX:%%5.3lf', $idx;
	push @gprint, sprintf 'COMMENT:%s\n', $hosts[$idx];
    }
}

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} roundtrip times [s] (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
                '--lower-limit=0',
		'--alt-autoscale',

		@def,

		@line,

		'COMMENT:\n',
		'COMMENT:\n',
		'COMMENT: AVG    MIN    MAX     host\n',
		@gprint
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

