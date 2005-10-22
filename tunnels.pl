#!/usr/bin/perl
# $Id: tunnels.pl,v 1.4 2005-10-22 21:20:58 mitch Exp $
#
# RRD script to display network statistics
# 2003-2004 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
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

# set variables
my $datafile_template = "$conf{DBPATH}/DEVICE.rrd";
my $picbase  = "$conf{OUTPATH}/tunnels-";
my @devices  = @{$conf{NETWORK_DEVICES}};

# global error variable
my $ERR;

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
		2020F0
		E0E000
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
    my ($device, $input_max, $output_max) = @{$tun};
    my $datafile = $datafile_template;

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
		  .":input_${device}#${color}:${device}",
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
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} tunnel network traffic (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		"--alt-autoscale",
		
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
