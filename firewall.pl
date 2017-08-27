#!/usr/bin/perl
#
# RRD script to display firewall statistics
#
# Copyright (C) 2004-2008, 2011, 2015, 2017  Christian Garbs <mitch@cgarbs.de>
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
my $datafile   = "$conf{DBPATH}/firewall.rrd";
my $picbase    = "$conf{OUTPATH}/firewall-";
my $ipt_script = 'sudo /usr/local/sbin/iptables-rejects.sh';

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
		 "DS:in_pkt:ABSOLUTE:600:0:U",
		 "DS:in_byte:ABSOLUTE:600:0:U",
		 "DS:out_pkt:ABSOLUTE:600:0:U",
		 "DS:out_byte:ABSOLUTE:600:0:U",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797",
		 'RRA:MAX:0.5:1:600',
		 'RRA:MAX:0.5:6:700',
		 'RRA:MAX:0.5:24:775',
		 'RRA:MAX:0.5:288:797'
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get data
open REJECTS, "$ipt_script |" or die "can't open $ipt_script: $!\n";
my ($in_pkt, $in_byte, $out_pkt, $out_byte) = (0, 0, 0, 0);
while (my $line = <REJECTS>) {
    chomp $line;
    my @line = split /\s+/, $line, 4;
    if ($line[0] eq 'INPUT') {
	$in_pkt   += $line[2];
	$in_byte  += $line[3];
    } elsif ($line[0] eq 'OUTPUT') {
	$out_pkt  += $line[2];
	$out_byte += $line[3];
    }
}
close REJECTS or die "can't close $ipt_script: $!\n";

# update database
RRDs::update($datafile,
	     "N:${in_pkt}:${in_byte}:${out_pkt}:${out_byte}"
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
		"--title=${hostname} packet filter rejects (last $scale)",
		'--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--slope-mode',

		"DEF:in_pkt=${datafile}:in_pkt:AVERAGE",
		"DEF:in_byteX=${datafile}:in_byte:AVERAGE",
		"DEF:out_pktX=${datafile}:out_pkt:AVERAGE",
		"DEF:out_byteX=${datafile}:out_byte:AVERAGE",

		'CDEF:in_byte=in_byteX,1024,/',
		'CDEF:out_pkt=0,out_pktX,-',
		'CDEF:out_byte=out_byteX,-1024,/',

		'AREA:in_byte#B0F0B0:in [Kbytes] ',
		'AREA:out_byte#B0B0F0:out [Kbytes] ',
		'COMMENT:\n',
		'LINE1:in_pkt#00D000:in [packets]',
		'LINE1:out_pkt#0000D0:out [packets]',
		'COMMENT:\n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
