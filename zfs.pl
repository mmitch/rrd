#!/usr/bin/perl
#
# RRD script to display ZFS zpool usage
#
# Copyright (C) 2019, 2023  Christian Garbs <mitch@cgarbs.de>
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
my %pools;
my ($snap, $ds, $res) = (0, 0, 0);
open my $zfs, '-|', '/sbin/zfs list -o name,usedsnap,usedds,usedrefreserv,available -H -p' or die "can't open zfs: $1";
while (my $line = <$zfs>) {
    chomp $line;
    my ($name, @values) = split /\t/, $line, 5;
    @values = map { $_ / (2 ** 20) } @values; # bytes -> megabytes

    $name =~ m,^([^/]+)(?:/|$),;
    my $pool = $1;

    $pools{$pool}->{snap}  += $values[0];
    $pools{$pool}->{ds}    += $values[1];
    $pools{$pool}->{res}   += $values[2];
    $pools{$pool}->{avail}  = $values[3]; # no addition, same for all pool members

}
close $zfs or die "can't close zfs: $1";

for my $pool (keys %pools) {
    
    # set variables
    my $datafile = "$conf{DBPATH}/zpool-${pool}.rrd";
    my $picbase  = "$conf{OUTPATH}/zpool-${pool}-";

    # generate database if absent
    if ( ! -e $datafile ) {
	# max 1024*1024*1024 MB (1 PetaByte) for each value
	RRDs::create($datafile,
		     'DS:snap:GAUGE:600:0:'.  (2 ** 30), # snapshot size
		     'DS:ds:GAUGE:600:0:'.    (2 ** 30), # data set size
		     'DS:res:GAUGE:600:0:' .  (2 ** 30), # ref reserved size
		     'DS:avail:GAUGE:600:0:'. (2 ** 30), # available space
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
    RRDs::update($datafile,
		 sprintf('N:%d:%d:%d:%d', $pools{$pool}->{snap}, $pools{$pool}->{ds}, $pools{$pool}->{res}, $pools{$pool}->{avail})
	);

    $ERR=RRDs::error;
    die "ERROR while updating $datafile: $ERR\n" if $ERR;

    # draw pictures
    foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
	my ($time, $scale) = @{$_};
	next if $time < $MINTIME;
	RRDs::graph($picbase . $scale . '.png',
		    "--start=-$time",
		    '--lazy',
		    '--imgformat=PNG',
		    "--title=${hostname} zpool ${pool} usage (last $scale)",
		    "--width=$conf{GRAPH_WIDTH}",
		    "--height=$conf{GRAPH_HEIGHT}",
		    '--color=BACK#f3f3f3f3',
		    '--color=SHADEA#f3f3f3f3',
		    '--color=SHADEB#f3f3f3f3',
		    '--lower-limit=0',
		    '--rigid',

		    "DEF:snap=${datafile}:snap:AVERAGE",
		    "DEF:dset=${datafile}:ds:AVERAGE",
		    "DEF:res=${datafile}:res:AVERAGE",
		    "DEF:avail=${datafile}:avail:AVERAGE",

		    'CDEF:snapgb=snap,'.(2 ** 20).',*',
		    'CDEF:dsetgb=dset,'.(2 ** 20).',*',
		    'CDEF:resgb=res,'.(2 ** 20).',*',
		    'CDEF:availgb=avail,'.(2 ** 20).',*',

		    'AREA:resgb#00A0E0:ref reserved',
		    'AREA:snapgb#90E000:snapshots:STACK',
		    'AREA:dsetgb#60D050:datasets:STACK',
		    'AREA:availgb#A0A0A0:available:STACK',
		    'COMMENT:\n',
		    'COMMENT:total size over all pools',
		);
	$ERR=RRDs::error;
	die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
    }
}
