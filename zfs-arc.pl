#!/usr/bin/perl
#
# RRD script to display ZFS ARC usage
#
# Copyright (C) 2026  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL v3 or later.
#
# This file is part of my rrd scripts (https://github.com/mmitch/rrd).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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
my $datafile = "$conf{DBPATH}/zfs-arc.rrd";
my $picbase_size = "$conf{OUTPATH}/zfs-arc-size-";
my $picbase_rate = "$conf{OUTPATH}/zfs-arc-rate-";

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

# collect data
my ($hits, $misses, $min, $max, $cur) = (0, 0, 0, 0, 0);
open my $arcstats, '<', '/proc/spl/kstat/zfs/arcstats' or die "can't open /proc/spl/kstat/zfs/arcstats: $!";
while (my $line = <$arcstats>) {
    chomp $line;
    my ($name, $type, $data) = split /\s+/, $line, 3;
    if ($name eq 'hits') {
	$hits = $data;
    } elsif ($name eq 'misses') {
	$misses = $data;
    } elsif ($name eq 'c_max') {
	$max = $data;
    } elsif ($name eq 'c_min') {
	$min = $data;
    } elsif ($name eq 'size') {
	$cur = $data;
    }
}
close $arcstats or die "can't open /proc/spl/kstat/zfs/arcstats: $!";

# generate database if absent
if ( ! -e $datafile ) {
    # 2 ** 40 =~ 10 ** 12 =~ 1 TB
    RRDs::create($datafile,
		 'DS:hits:GAUGE:600:0:U',   # cache hits (no sensible max limit)
		 'DS:misses:GAUGE:600:0:U', # cache misses (no sensible max limit)
		 'DS:min:GAUGE:600:0:'. (2 ** 40), # min size in bytes
		 'DS:max:GAUGE:600:0:'. (2 ** 40), # max size in bytes
		 'DS:cur:GAUGE:600:0:'. (2 ** 40), # actual size in bytes
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797'
	);
    
    $ERR=RRDs::error;
    die "ERROR while creating $datafile: $ERR\n" if $ERR;
    print "created $datafile\n";
}

# update database
RRDs::update($datafile, sprintf('N:%d:%d:%d:%d:%d', $hits, $misses, $min, $max, $cur));

$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase_size . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} zfs ARC cache size (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',

		"DEF:min=${datafile}:min:MIN",
		"DEF:max=${datafile}:max:MAX",
		"DEF:cur=${datafile}:cur:AVERAGE",

		'CDEF:stack=max,min,-',

#		'LINE1:min#00F0F0:min cache [bytes]',
#		'LINE1:max#0000F0:max cache [bytes]',
		'AREA:min#88888800',
		'STACK:stack#AAAAAA:cache min/max [bytes]',
		'LINE2:cur#00F000:current cache [bytes]\n',
	);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;

    RRDs::graph($picbase_rate . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} zfs ARC hit rate (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--left-axis-format=%2.0lf%%',

		"DEF:hits=${datafile}:hits:AVERAGE",
		"DEF:misses=${datafile}:misses:AVERAGE",

		'CDEF:hitrate=hits,hits,misses,+,/,100,*',

		'LINE2:hitrate#F000F0:cache hit rate',
		'GPRINT:hitrate:MIN: min=%.02lf%%',
		'GPRINT:hitrate:AVERAGE: avg=%.02lf%%',
		'GPRINT:hitrate:MAX: max=%.02lf%%\n',
	);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
