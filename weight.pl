#!/usr/bin/perl -w
use strict;
use Time::Local;

use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/weight.rrd";
my $picbase  = "$conf{OUTPATH}/weight-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# half a day's seconds
my $STEP = 60 * 60 * 12;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 '-b 1188662000',
		 '-s ' . $STEP,
		 'DS:weight:GAUGE:'.($STEP*2).':0:200',
		 'RRA:AVERAGE:0.5:1:750',   # roughly more than a year on half-a-day-base
		 'RRA:AVERAGE:0.5:2:1500',  # roughly four years on a daily base
		 'RRA:AVERAGE:0.5:14:550',  # roughly ten years on a weekly base
		 'RRA:AVERAGE:0.5:56:1300', # roughly 100 years on a monthly base
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

sub put($$)
{
    my ($time, $val) = (@_);
    RRDs::update($datafile, "$time:$val");
    $ERR=RRDs::error;
    die "ERROR while updating $datafile: $ERR\n" if $ERR;
    
}

my $lastupdate = RRDs::info($datafile)->{'last_update'};
my $lasttime = undef;
my $lastval = undef;

while (my $line = <>) {
    chomp $line;
    my ($date, $val) = split /\s+/, $line;
    my $time = timelocal(0, 0, 6 + 12 * ((lc substr( $date, 8, 1 )) eq 'b'), substr($date, 6, 2), substr($date, 4, 2)-1, substr($date, 0, 4));
    
    if (defined $lasttime) {
	
	my $quot = ($val - $lastval) / ($time - $lasttime);
	
	my $t = $lasttime + $STEP;
	while ($t <= $time) {
	    my $v = $lastval + $quot * ($t - $lasttime);
	    put($t, $v);
	    $t += $STEP;
	}
	
    } else {
	if ($time <= $lastupdate) {
	    next;
	}
	put($time, $val);
    }
    
    $lasttime = $time;
    $lastval = $val;
    
}

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} operator weight (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--alt-autoscale',
		'--slope-mode',
#                '--lower-limit=0',
#                '--upper-limit=100',

		"DEF:weight=$datafile:weight:AVERAGE",
		'LINE2:weight#0000D0:mass [kg]',

		'COMMENT:\n',
		'COMMENT: ',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

