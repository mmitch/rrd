#!/usr/bin/perl
#
# RRD script to display io stats
#
# Copyright (C) 2003, 2004, 2006-2008, 2011, 2015, 2017, 2019  Christian Garbs <mitch@cgarbs.de>
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

# subroutines

sub proc_to_map {
    my ($keyline, $valueline) = @_;

    chomp $keyline;
    chomp $valueline;
    
    my @keys   = split /\s+/, $keyline;
    my @values = split /\s+/, $valueline;

    my $map = {};
    while (@keys) {
	my $key   = shift @keys;
	my $value = shift @values;
	$map->{$key} = $value;
    }

    return $map;
}

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/netstat.rrd";
my $picbase  = "$conf{OUTPATH}/netstat-";

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
		 "DS:active_open:COUNTER:600:0:5000000",
		 "DS:passive_open:COUNTER:600:0:5000000",
		 "DS:failed_conn:COUNTER:600:0:5000000",
		 "DS:reset_in:COUNTER:600:0:5000000",
		 "DS:reset_out:COUNTER:600:0:5000000",
		 "DS:error_in:COUNTER:600:0:5000000",
		 "DS:bad_checksum_in:COUNTER:600:0:5000000",
		 "DS:segment_in:COUNTER:600:0:5000000",
		 "DS:segment_out:COUNTER:600:0:5000000",
		 "DS:segment_retransmit:COUNTER:600:0:5000000",
		 "DS:established:GAUGE:600:0:500000",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get netstats
open my $proc, '<', '/proc/net/snmp' or die "can't open `/proc/net/snmp': $!\n";
my $line;
while ($line = <$proc>) {
    last if $line =~ /Tcp:/;
}
my $nextline = <$proc>;
close $proc or die "can't open `/proc/net/snmp': $!\n";

my $values = proc_to_map($line, $nextline);

# update database
RRDs::update($datafile,
	     join(':',
		  'N',
		  $values->{ActiveOpens},
		  $values->{PassiveOpens},
		  $values->{AttemptFails},
		  $values->{EstabResets},
		  $values->{OutRsts},
		  $values->{InErrs},
		  $values->{InCsumErrors},
		  $values->{InSegs},
		  $values->{OutSegs},
		  $values->{RetransSegs},
		  $values->{CurrEstab})
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} TCP connections (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--slope-mode',
		'--logarithmic',
		'--units=si',

                "DEF:active_open=${datafile}:active_open:AVERAGE",
                "DEF:passive_open=${datafile}:passive_open:AVERAGE",
                "DEF:failed_conn=${datafile}:failed_conn:AVERAGE",
                "DEF:reset_in=${datafile}:reset_in:AVERAGE",
                "DEF:reset_out=${datafile}:reset_out:AVERAGE",
                "DEF:error_in=${datafile}:error_in:AVERAGE",
                "DEF:bad_checksum_in=${datafile}:bad_checksum_in:AVERAGE",
#                "DEF:segment_in=${datafile}:segment_in:AVERAGE",
#                "DEF:segment_out=${datafile}:segment_out:AVERAGE",
                "DEF:segment_retransmit=${datafile}:segment_retransmit:AVERAGE",
                "DEF:established=${datafile}:established:AVERAGE",

                'LINE1:established#60D050:established',
                'LINE1:active_open#C09000:open act ',
                'LINE1:reset_in#8040D0:reset in ',
                'LINE1:bad_checksum_in#E00070:bad checksum in:dashes=2',
                'LINE1:error_in#E00070:error in',

		'COMMENT:\n',
		
                'LINE1:failed_conn#FF9000:failed conn',
                'LINE1:passive_open#E0C000:open pasv',
                'LINE1:reset_out#4050D0:reset out',
                'LINE1:segment_retransmit#808080:segment retransmit:dashes=2',
#                'LINE1:segment_in#7000E0:sgmt in',
#                'LINE1:segment_out#C000A0:sgmt out',

		'COMMENT:\n',
		
	);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
