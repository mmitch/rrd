#!/usr/bin/perl
#
# RRD script to display network statistics
#
# Copyright (C) 2005, 2007, 2008, 2011, 2015-2017  Christian Garbs <mitch@cgarbs.de>
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
# This script should be run regularly.
# It DOES NOT save any data, it's graph-only.
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile_template = "$conf{DBPATH}/DEVICE.rrd";
my $picbase  = "$conf{OUTPATH}/tunnels-";
my @devices  = @{$conf{NETWORK_DEVICES}};

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

# remove non-tuns
@devices = grep { @{$_}[0] =~ /^tun/ } @devices;

# set up cache
my (@def, @cdef, @line1, @line2);

# set up colorspace
my $drawn = 0;
my @colors = qw(
		000000
		AAAAAA
		F0A000
		60D050
		E00070
		E0E000
		2020F0
		FFFF00
		FF00FF
		00FF00
		0000FF
		00FFFF
		900000
		C0C0C0
		009000
		000090
		909000
		900090
		009090
		FF0000
		000000
		000000
		000000
		000000
		000000
		000000
		000000
		000000
		000000
		000000
	       );

# iterate over all given devices
foreach my $tun ( @devices ) {

    # get current variables
    my ($device, $input_max, $output_max, $name) = @{$tun};
    my $datafile = $datafile_template;

    $name = $device unless defined $name;

    $datafile =~ s/DEVICE/$device/;

    my $color = $colors[$drawn];
    
    push @def, (
		"DEF:input_${device}=${datafile}:input:AVERAGE",
		"DEF:outputx_${device}=${datafile}:output:AVERAGE"
		);
    
    push @cdef, (
		 "CDEF:output_${device}=0,outputx_${device},-"
		 );

    push @line1, (
		  ($drawn ? 'STACK' : 'AREA')
		  .":input_${device}#${color}:${name}",
		 );

    push @line2, (
		  ($drawn ? 'STACK' : 'AREA')
		  .":output_${device}#${color}:",
		 );

    $drawn++;
}

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} tunnel network traffic (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--alt-autoscale',
#		'--logarithmic',
#		'--units=si',
		
		@def,
		
		@cdef,
		
		@line1,
		@line2,

		'COMMENT:\n',
		'COMMENT:[octets/sec]'
		
		);
    $ERR=RRDs::error;
    die "ERROR while drawing tunnels $time: $ERR\n" if $ERR;
}
