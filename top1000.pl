#!/usr/bin/perl -w
#
# RRD script to display top1000.org usenet s
# 2011 Copyright (C)  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL v3 or later.
#
# This script should be run once a day.
#

use strict;
use warnings;
use RRDs;
use LWP::Simple;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/top1000.rrd";
my $picbase  = "$conf{OUTPATH}/top1000-";

my $mysite = $conf{TOP1000_ME};
my @sites = @{$conf{TOP1000_SITES}};
if (@sites < 10) {
    $sites[9] = undef;
}

my $url_participants = 'http://top1000.anthologeek.net/participants.current.txt';
my $url_top1000 =      'http://top1000.anthologeek.net/top1000.current.txt';

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 "--step=86400",
		 "--start=1302345000",
		 "DS:submitted:COUNTER:160000:0:U",
		 "DS:site0:GAUGE:160000:0:1000",
		 "DS:site1:GAUGE:160000:0:1000",
		 "DS:site2:GAUGE:160000:0:1000",
		 "DS:site3:GAUGE:160000:0:1000",
		 "DS:site4:GAUGE:160000:0:1000",
		 "DS:site5:GAUGE:160000:0:1000",
		 "DS:site6:GAUGE:160000:0:1000",
		 "DS:site7:GAUGE:160000:0:1000",
		 "DS:site8:GAUGE:160000:0:1000",
		 "DS:site9:GAUGE:160000:0:1000",
		 'RRA:AVERAGE:0.5:1:370',
		 'RRA:AVERAGE:0.5:7:288',
		 'RRA:MIN:0.5:1:370',
		 'RRA:MIN:0.5:7:288',
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get data
my $content = get($url_participants) or die "Couldn't get $url_participants!";
my $submitted = 0;
foreach my $line (split /\n/, $content) {
    if ($line =~ /^(\d+)\s+(\S+)/) {
	if ($2 eq $mysite) {
	    $submitted = $1;
	}
    }
}

$content = get($url_top1000) or die "Couldn't get $url_top1000!";
my %site;
foreach my $line (split /\n/, $content) {
    if ($line =~ /^\s+(\d+)\s+(\d+\.\d+)\s+(\S+)/) {
	my ($pos, $weight, $site) = ($1, $2, $3);
	$site{$site} = $pos;
    }
}

# update database
RRDs::update($datafile,
	     "N:$submitted:" . join (':', map { (defined $_ and defined $site{$_}) ? $site{$_} : 'U' } @sites )
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
my (@def, @line);
foreach my $site (@sites) {
    if (defined $site) {
	my $color = $colors[$drawn];
	push @def, sprintf 'DEF:site%d_=%s:site%d:AVERAGE', $drawn, $datafile, $drawn;
	push @def, sprintf 'CDEF:site%d=0,site%d_,-', $drawn, $drawn;
	push @line, sprintf 'LINE2:site%d#%s:%s', $drawn, $color, $site;
	$drawn ++;
    }
}

# draw pictures
foreach ( [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		'--upper-limit=0',
		'--lower-limit=-1000',
		"--title=${hostname} usenet top1000 stats (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		
#		"DEF:submit_avg_=${datafile}:submitted:AVERAGE",
#		"DEF:submit_min_=${datafile}:submitted:MIN",
#		'CDEF:submit_avg=submit_avg_,10,/',
#		'CDEF:submit_min=submit_min_,10,/',

		@def,

#		'LINE2:submit_min#FFD0D0:min submit',
#		'LINE1:submit_avg#D0FFD0:avg submit',

		@line,

		'COMMENT:\n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
