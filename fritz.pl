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

use Net::Fritz::Box;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/fritz.rrd";
my $picbase  = "$conf{OUTPATH}/connecttime-"; # supersedes old 'connecttime.pl' script!
my $picbase2 = "$conf{OUTPATH}/fritz-";
my $ipfile   = "$conf{FRITZ_IP_FILE}";

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
    
    my $device = $box->discover;
    $device->errorcheck;

    return $device;
}

sub get_service($$) {
    my ($fritz, $service_name) = @_;

    my $service = $fritz->find_service($service_name);
    if ($service->error) {
	warn "service $service_name not found: " . $service->error;
	return 0;
    }

    return $service;
}

sub call($$) {
    my ($service, $action) = @_;
    
    my $response = $service->call($action);
    if ($response->error) {
	warn "call $action on service " . $service->serviceId . " with error: " . $response->error;
	return 0;
    }

    return $response->data;
}
    
sub call_wrapped($$$) {
    my ($fritz, $service_name, $action) = @_;

    my $service = get_service($fritz, $service_name);
    return 0 unless $service;

    return call($service, $action);
}

sub get_link_type($) {
    my ($fritz) = @_;

    my $dsl_link_info = call_wrapped($fritz, ':WANDSLLinkConfig:', 'GetDSLLinkInfo');
    
    return 0 unless $dsl_link_info;
    return 0 unless $dsl_link_info->{'NewLinkStatus'} eq 'Up';

    return $dsl_link_info->{'NewLinkType'};
}

sub get_wan_connection($) {
    my ($fritz) = @_;

    my $link_type = get_link_type($fritz);
    return 0 unless $link_type;

    my $service_name = {
	'PPPoE' => ':WANPPPConnection:',
	'IP'    => ':WANIPConnection:',
    }->{$link_type};

    return 0 unless defined $service_name;

    return get_service($fritz, $service_name);
}

sub get_external_ip($) {
    my ($wan_connection_service) = @_;

    my $external_ip = call($wan_connection_service, 'GetExternalIPAddress');

    return '' unless $external_ip;
    
    return $external_ip->{'NewExternalIPAddress'};
}

sub get_uptime($) {
    my ($wan_connection_service) = @_;

    my $uptime = call($wan_connection_service, 'GetStatusInfo');

    return 0 unless $uptime;
    
    return $uptime->{'NewUptime'};
}

sub get_wan_common_if($) {
    my ($fritz) = @_;

    return get_service($fritz, ':WANCommonInterfaceConfig:');
}

sub get_bytes_in($) {
    my ($wan_common_if) = @_;

    my $response = call($wan_common_if, 'GetTotalBytesReceived');

    return 0 unless $response;

    return $response->{'NewTotalBytesReceived'};
}

sub get_bytes_out($) {
    my ($wan_common_if) = @_;

    my $response = call($wan_common_if, 'GetTotalBytesSent');

    return 0 unless $response;

    return $response->{'NewTotalBytesSent'};
}

sub write_to_file($$) {
    my ($file, $content) = @_;

    open FILE, '>', $file or die "error opening to `$file': $!";
    print FILE $content;
    close FILE or die "error opening to `$file': $!";
}

############################### subroutines ###############################

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if (! -e $datafile ) {
    RRDs::create($datafile,
		 'DS:connecttime:GAUGE:600:0:31536000', # 1 year
		 'DS:input:COUNTER:600:0:15000000',     # about 100MBit
		 'DS:output:COUNTER:600:0:15000000',    # about 100MBit (symmetric)
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

my $fritz = fritz_connect();

my $wan = get_wan_connection($fritz);
if ($wan) {
    write_to_file($ipfile, get_external_ip($wan));
    $connecttime = get_uptime($wan);
}

my $common = get_wan_common_if($fritz);
if ($common) {
    $input = get_bytes_in($common);
    $output = get_bytes_out($common);
}

# update database
RRDs::update($datafile,
             "N:$connecttime:$input:$output"
             );

die "ERROR while adding $datafile $connecttime: $ERR\n" if $ERR;

# draw pictures (connecttime)
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
                "--start=-${time}",
                '--lazy',
                '--imgformat=PNG',
                "--title=${hostname} time since last connect/IP change (last $scale)",
                '--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",

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
    RRDs::graph($picbase2 . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} FRITZ!Box network traffic (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
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

