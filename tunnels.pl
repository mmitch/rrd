#!/usr/bin/perl
# $Id: tunnels.pl,v 1.3 2005-10-22 17:47:37 mitch Exp $
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
my $PI = 3.14159265356237;
my $count = scalar @devices;
$count-- if $count > 1;

# iterate over all given devices
foreach my $tun ( @devices ) {

    # get current variables
    my ($device, $input_max, $output_max) = @{$tun};
    my $datafile = $datafile_template;

    $datafile =~ s/DEVICE/$device/;

    my $color = sprintf '%02X%02X%02X'
	, 128 + (96 * sin ( 1 + $PI * ( $drawn/$count ) ) )
	, 128 + (96 * sin (     $PI * ( $drawn/$count ) ) )
	, 128 - (96 * sin ( 2 + $PI * ( $drawn/$count ) ) );
    
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
