#!/usr/bin/perl
#
# RRD script to display FRITZ!Box connection stats
# 2017 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

use Net::Fritz::Box 0.0.8;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/fritz.rrd";
my $picbase  = "$conf{OUTPATH}/connecttime-"; # supersedes old 'connecttime.pl' script!
my $picbase2 = "$conf{OUTPATH}/fritz-";
my $ipfile   = "$conf{FRITZ_IP_FILE}";

# global error variable
my $ERR;

# global Net::Fritz::Device instance
my $fritz;

############################### subroutines ###############################

sub fritz_connect() {
    # get credentials
    my ($user, $pass);
    my $rcfile = $ENV{HOME}.'/.fritzrc';
    if (-r $rcfile) {
	open FRITZRC, '<', $rcfile or die $!;
	while (my $line = <FRITZRC>) {
	    chomp $line;
	    if ($line =~ /^(\S+)\s*=\s*(.*?)$/) {
		if ($1 eq 'username') {
		    $user = $2;
		}
		elsif ($1 eq 'password') {
		    $pass = $2
		}
	    }
	}
	close FRITZRC or die $!;
    }
    
    # connect to FRITZ!Box
    my $box = Net::Fritz::Box->new(
	username => $user,
	password => $pass
	);
    $box->errorcheck;
    
    return $box;
}

sub get_link_type() {
    my $dsl_link_info = $fritz->call(':WANDSLLinkConfig:', 'GetDSLLinkInfo');
    
    return 0 if $dsl_link_info->error;
    return 0 unless $dsl_link_info->data->{'NewLinkStatus'} eq 'Up';

    return $dsl_link_info->data->{'NewLinkType'};
}

sub get_wan_type() {
    my $link_type = get_link_type();
    return 0 unless $link_type;

    my $service_name = {
	'PPPoE' => ':WANPPPConnection:',
	'IP'    => ':WANIPConnection:',
    }->{$link_type};

    return 0 unless defined $service_name;

    return $service_name;
}

sub get_external_ip($) {
    my ($wan_type) = @_;

    my $external_ip = $fritz->call($wan_type, 'GetExternalIPAddress');

    return '' if $external_ip->error;
    
    return $external_ip->data->{'NewExternalIPAddress'};
}

sub get_uptime($) {
    my ($wan_type) = @_;

    my $uptime = $fritz->call($wan_type, 'GetStatusInfo');

    return 0 if $uptime->error;
    
    return $uptime->data->{'NewUptime'};
}

sub get_bytes_in() {
    my $response = $fritz->call(':WANCommonInterfaceConfig:', 'GetTotalBytesReceived');

    return 0 if $response->error;

    return $response->data->{'NewTotalBytesReceived'};
}

sub get_bytes_out() {
    my $response = $fritz->call(':WANCommonInterfaceConfig:', 'GetTotalBytesSent');

    return 0 if $response->error;

    return $response->data->{'NewTotalBytesSent'};
}

sub write_to_file($$) {
    my ($file, $content) = @_;

    open FILE, '>', $file or die "error opening to `$file': $!";
    print FILE $content;
    close FILE or die "error opening to `$file': $!";
}

############################### subroutines ###############################

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
if (! -e $datafile ) {
    RRDs::create($datafile,
		 'DS:connecttime:GAUGE:600:0:31536000', # 1 year
		 'DS:input:DERIVE:600:0:15000000',      # about 100MBit
		 'DS:output:DERIVE:600:0:15000000',     # about 100MBit (symmetric)
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 'RRA:MAX:0.5:1:600',
		 'RRA:MAX:0.5:6:700',
		 'RRA:MAX:0.5:24:775',
		 'RRA:MAX:0.5:288:797'
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# gather data
my ($connecttime, $input, $output) = (0, 0, 0);

$fritz = fritz_connect();

my $wan_type = get_wan_type();
if ($wan_type) {
    write_to_file($ipfile, get_external_ip($wan_type));
    $connecttime = get_uptime($wan_type);
}

$input = get_bytes_in();
$output = get_bytes_out();

# update database
RRDs::update($datafile,
             "N:$connecttime:$input:$output"
             );

die "ERROR while adding $datafile $connecttime: $ERR\n" if $ERR;

# draw pictures (connecttime)
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} time since last connect/IP change (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',

                "DEF:seconds=${datafile}:connecttime:AVERAGE",
		"DEF:oldseconds=${datafile}:connecttime:AVERAGE:end=now-${time}s:start=end-${time}s",

		"SHIFT:oldseconds:$time",
		'CDEF:hours=seconds,3600,/',
		'CDEF:oldhours=oldseconds,3600,/',

                'AREA:hours#00D000:connection time [h]',
                "LINE:oldhours#D0D0D0:connection time [h] previous $scale",
		'COMMENT:\n',
		'COMMENT:\n',
                );
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

# draw pictures (I/O)
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase2 . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} FRITZ!Box network traffic (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--alt-autoscale',
#		'--logarithmic',
#		'--units=si',
		
		"DEF:input=${datafile}:input:AVERAGE",
		"DEF:outputx=${datafile}:output:AVERAGE",
		"DEF:input_max=${datafile}:input:MAX",
		"DEF:output_maxx=${datafile}:output:MAX",
		
		'CDEF:output=0,outputx,-',
		'CDEF:output_max=0,output_maxx,-',
		
		'AREA:input_max#B0F0B0:max input [bytes/sec]',
		'AREA:output_max#B0B0F0:max output [bytes/sec]',
		'COMMENT:\n',
		'AREA:input#00D000:avg input [bytes/sec]',
		'AREA:output#0000D0:avg output [bytes/sec]',
		'COMMENT:\n',
	);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

