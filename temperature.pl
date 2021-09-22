#!/usr/bin/perl
#
# RRD script to display hardware temperature
#
# Copyright (C) 2003-2009, 2011, 2015, 2017, 2021  Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/temperature.rrd";
my $picbase  = "$conf{OUTPATH}/temperature-";

my $cmdline  = q%

sensors -j | jq -r --stream '
# suffix of readings interesting to us
def reading_suffix: "_input$" ;

# in streaming mode, all objects are streamed as [[path], value] elements, with path having multiple parts
def get_path:  .[0] ;
def get_value: .[1] ;

# extract information from stream elements
def get_sensor_name:    get_path  | .[0]  ; # first path element
def get_reading_name:   get_path  | .[2]  ; # third path element
def get_short_reading_name: get_reading_name | sub(reading_suffix; "") ; # remove suffix

# select only those stream elements which contain current values
select( get_reading_name | strings | test(reading_suffix) )
| select( get_value | numbers )

# combine each sensor and reading name with their temperature
| [ get_sensor_name + "::" + get_short_reading_name , get_value ]

# convert name/value pairs to space separated strings
| join(" ")

' %;

# same script in one line
#my $cmdline  = q% sensors -j | jq -r --stream 'def regex: "_input$"; def path: .[0]; def value: .[1]; def sensor: path|.[0]; def reading: path|.[2]; def reading_short: reading|sub(regex;""); select(reading|strings|test(regex)) | select(value|numbers) | [sensor+"::"+reading_short,value] | join(" ")' %;

# same script in short form
#my $cmdline  = q% sensors -j | jq -r --stream 'select(.[0]|.[2]|strings|test("_input$")) | select(.[1]|numbers) | [(.[0]|.[0])+"::"+(.[0]|.[2]|sub("_input$";"")),(.[1]|round)] | join(" ")' %;

# alternative script with same outcome
# my $cmdline  = q% sensors -j | jq -r '(paths | select(length == 3) | select( .[2] | test("_input$"))) as $inputs | [ ($inputs | .[0]+"::"+ (.[2]| sub("_input$";"")) ), getpath($inputs) ] | join(" ")' %;

my $cpus     = $conf{SENSOR_MAPPING_CPU};
my $fans     = $conf{SENSOR_MAPPING_FAN};
my $temps    = $conf{SENSOR_MAPPING_TEMP};
my $disks    = $conf{SENSOR_MAPPING_DISK};

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
    # max 9000 for fan, 100 for temperature
    RRDs::create($datafile,
		 "DS:fan0:GAUGE:600:0:9000",
		 "DS:fan1:GAUGE:600:0:9000",
		 "DS:fan2:GAUGE:600:0:9000",
		 "DS:fan3:GAUGE:600:0:9000",
		 "DS:temp0:GAUGE:600:10:100",
		 "DS:temp1:GAUGE:600:10:100",
		 "DS:temp2:GAUGE:600:10:100",
		 "DS:temp3:GAUGE:600:10:100",
		 "DS:cpu0:GAUGE:600:10:100",
		 "DS:cpu1:GAUGE:600:10:100",
		 "DS:cpu2:GAUGE:600:10:100",
		 "DS:cpu3:GAUGE:600:10:100",
		 "DS:disk00:GAUGE:600:10:100",
		 "DS:disk01:GAUGE:600:10:100",
		 "DS:disk02:GAUGE:600:10:100",
		 "DS:disk03:GAUGE:600:10:100",
		 "DS:disk04:GAUGE:600:10:100",
		 "DS:disk05:GAUGE:600:10:100",
		 "DS:disk06:GAUGE:600:10:100",
		 "DS:disk07:GAUGE:600:10:100",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# read sensor data
my %val;
open my $sensors, '-|', "$cmdline" or die "can't open sensors/jq: $!\n";
while (my $line = <$sensors>) {
    chomp $line;
    my ($key, $value, $rest) = split / /, $line, 3;
    die "unparseable line <$line>" if defined $rest;
    $val{$key} = $value;
}
close $sensors or die "can't close sensors/jq: $!\n";

# prepare values
sub getval($)
{
    my $key = shift;
    return 'U' unless defined $key;
    return 'U' unless exists $val{$key};
    return $val{$key};
}

my $rrdstring = 'N';
foreach my $i (0..3) {
    $rrdstring .= ':' . getval($fans->[$i]);
}

foreach my $i (0..3) {
    $rrdstring .= ':' . getval($temps->[$i]);
}

foreach my $i (0..3) {
    $rrdstring .= ':' . getval($cpus->[$i]);
}

foreach my $i (0..7) {
    $rrdstring .= ':' . getval($disks->[$i]);
}

# update database
RRDs::update($datafile,
	     $rrdstring
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
		"--title=${hostname} temperature (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--alt-autoscale',
		'--slope-mode',

		"DEF:fan0x=${datafile}:fan0:AVERAGE",
		"DEF:fan1x=${datafile}:fan1:AVERAGE",
		"DEF:fan2x=${datafile}:fan2:AVERAGE",
#		"DEF:fan3x=${datafile}:fan3:AVERAGE",
		"DEF:temp0=${datafile}:temp0:AVERAGE",
		"DEF:temp1=${datafile}:temp1:AVERAGE",
		"DEF:temp2=${datafile}:temp2:AVERAGE",
#		"DEF:temp3=${datafile}:temp3:AVERAGE",
		"DEF:cpu0=${datafile}:cpu0:AVERAGE",
		"DEF:cpu1=${datafile}:cpu1:AVERAGE",
#		"DEF:cpu2=${datafile}:cpu2:AVERAGE",
#		"DEF:cpu3=${datafile}:cpu3:AVERAGE",
		"DEF:disk00=${datafile}:disk00:AVERAGE",
		"DEF:disk01=${datafile}:disk01:AVERAGE",
		"DEF:disk02=${datafile}:disk02:AVERAGE",
#		"DEF:disk03=${datafile}:disk03:AVERAGE",
#		"DEF:disk04=${datafile}:disk04:AVERAGE",
#		"DEF:disk05=${datafile}:disk05:AVERAGE",
#		"DEF:disk06=${datafile}:disk06:AVERAGE",
#		"DEF:disk07=${datafile}:disk07:AVERAGE",

		'CDEF:fan0=fan0x,50,/',
		'CDEF:fan1=fan1x,50,/',
		'CDEF:fan2=fan2x,50,/',
#		'CDEF:fan3=fan3x,50,/',

#		'CDEF:fan1s=fan0,fan1,-,0,300,LIMIT',
#		'CDEF:cpu1s=cpu0,cpu1,-',
#		'CDEF:temp1s=temp0,temp1,-',

#		'AREA:fan0#8888FF00',
#		'STACK:fan1s#8888FF:fan [50r/m]',

		'LINE1:cpu0#FF8888:cpu cores[°C]',
		'LINE1:cpu1#FF8888',
#		'AREA:cpu0#FF888800',
#		'STACK:cpu1s#FF8888:cpu core [°C]',

		'LINE1:temp0#444444:board [°C]',
		'LINE1:temp1#444444',
		'LINE1:temp2#444444',
#		'AREA:temp0#44444400',
#		'STACK:temp1s#444444:board [°C]',

		'LINE1:fan0#8888FF:fans [50rpm]',
		'LINE1:fan1#8888FF',
		'LINE1:fan2#8888FF',

		'COMMENT:\n',

		'LINE2:disk00#0000FF:sda [°C]',
		'LINE2:disk01#FFFF00:sdb [°C]',
		'LINE2:disk02#FF0000:sdc [°C] ',
#		'LINE2:disk03#00FF00:sdd [°C]',

		'COMMENT:\n',

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
