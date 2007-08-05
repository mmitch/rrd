#!/usr/bin/perl
# $Id: roundtrip.pl,v 1.4 2007-08-05 16:10:18 mitch Exp $
#
# RRD script to display disk usage
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
my $datafile = "$conf{DBPATH}/roundtrip.rrd";
my $picbase  = "$conf{OUTPATH}/roundtrip-";

# watch these paths
my @hosts = @{$conf{'ROUNDTRIP_HOSTS'}};
# @hosts = grep { $_ ne '' } @hosts;
my @time;

# global error variable
my $ERR;

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
	       );

# draw which values?
my (@def, @line, @gprint);
for my $idx ( 0..19 ) {
    if ( $hosts[$idx] ne '' ) {
	my $color = $colors[$drawn];
	push @def, sprintf 'DEF:rtt%02d=%s:rtt%02d:AVERAGE', $idx, $datafile, $idx;
	push @line, sprintf 'LINE2:rtt%02d#%s:%s', $idx, $color, $hosts[$idx];
	$drawn ++;
	push @gprint, sprintf 'GPRINT:rtt%02d:AVERAGE:%%3.0lf', $idx;
	push @gprint, sprintf 'GPRINT:rtt%02d:MIN:%%3.0lf', $idx;
	push @gprint, sprintf 'GPRINT:rtt%02d:MAX:%%3.0lf', $idx;
	push @gprint, sprintf 'COMMENT:%s\n', $hosts[$idx];
    }
}

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} roundtrip times [s] (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
                '--lower-limit=0',

		@def,

		@line,

		'COMMENT:\n',
		'COMMENT:\n',
		'COMMENT:AVG  MIN  MAX  mount\n',
		@gprint
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

