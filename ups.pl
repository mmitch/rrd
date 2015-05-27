#!/usr/bin/perl
#
# RRD script to display ups values
# Copyright (C) 2003, 2011, 2015  Christian Garbs <mitch@cgarbs.de>
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

# Configurable stuff here
my $datafile = "$conf{DBPATH}/ups.rrd";
my $picbase  = "$conf{OUTPATH}/ups-";

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
    RRDs::create($datafile,
		 "DS:utility:GAUGE:600:1:500",
		 "DS:outvolt:GAUGE:600:1:500",
		 "DS:battpct:GAUGE:600:0:110",
		 "DS:battvolt:GAUGE:600:1:500",
		 "DS:acfreq:GAUGE:600:1:100",
		 "DS:loadpct:GAUGE:600:0:500",
		 "DS:online:GAUGE:600:0:1",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}


## old and annoying BELKIN tool
# get UPS status
#my $infile = '/etc/belkin/belkin.q1';
#open UPS, '<', $infile or die "can't read from `$infile': $!\n";
#my $line = <UPS>;
#$line =~ tr/0-9 .//dc;
#my @field = split /\s+/, $line;
#close UPS or die "can't close `$infile': $!\n";
#
# set values
#my %status = (
#	      'battery.charge'  => $field[6]*100/32,
#	      'battery.voltage' => $field[5],
#	      'input.frequency' => $field[4],
#	      'input.voltage'   => $field[0],
#	      'output.voltage'  => $field[1],
#	      'output.frequency'=> 0,
#	      'ups.load'        => $field[3],
#	      'ups.status'      => $field[7] eq '00001000' ? 1 : 0
#	      );



## all hail nut!
# set empty values
my %status = (
    'battery.charge'   => 0,
    'battery.voltage'  => 0,
    'input.frequency'  => 0,
    'input.voltage'    => 0,
    'output.voltage'   => 0,
    'output.frequency' => 0,
    'ups.load'         => 0,
    'ups.status'       => 0
    );


# get UPS status
my $cmd = 'upsc eaton@localhost';
open UPS, '-|', $cmd or die "can't read from `$cmd': $!\n";
while (my $line = <UPS>) {
    chomp $line;
    my ($key, $value) = split /: /, $line, 2;
    $status{$key} = $value;
}
close UPS or die "can't close `$cmd': $!\n";

$status{'ups.status'} = ($status{'ups.status'} =~ /^OL/) ? 1 : 0;


# update database
RRDs::update($datafile,
	     "N:$status{'input.voltage'}:$status{'output.voltage'}:$status{'battery.charge'}:$status{'battery.voltage'}:$status{'input.frequency'}:$status{'ups.load'}:$status{'ups.status'}"
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
		"--title=${hostname} ups status (last $scale)",
		'--base=1000',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--lower-limit=0',
		'--slope-mode',

#		"DEF:volt_i=${datafile}:utility:AVERAGE",
		"DEF:volt_o=${datafile}:outvolt:AVERAGE",
#		"DEF:volt_b=${datafile}:battvolt:AVERAGE",
		"DEF:batt=${datafile}:battpct:AVERAGE",
		"DEF:load=${datafile}:loadpct:AVERAGE",
#		"DEF:freq=${datafile}:acfreq:AVERAGE",
		"DEF:status=${datafile}:online:AVERAGE",

#		'CDEF:volt_in=volt_i,150,-',
		'CDEF:volt_out=volt_o,150,-',
#		'CDEF:volt_bat=volt_b,2,*',
		'CDEF:online=status,100,*',
		'CDEF:offline=100,online,-',

		'AREA:online#D0FFD0:online [%]  ',
		'STACK:offline#FFD0D0:offline [%] ',
		'LINE3:volt_out#D0D0FF:output [V-150]',
#		'LINE1:volt_in#0000A0:input [V-150]\n',
# 		'LINE2:freq#A0A0A0:AC freq [Hz]',
#		'LINE2:volt_bat#00C800:battery [V*2] ',
		'LINE2:load#0000F0:load [%]    ',
		'LINE2:batt#F00000:battery charge [%]',
                'COMMENT:\n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
