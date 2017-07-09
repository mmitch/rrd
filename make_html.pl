#!/usr/bin/perl -w
#
# Generate HTML pages for rrd stats
#
use strict;
use warnings;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $path     = $conf{OUTPATH};
my @rrd      = @{$conf{MAKEHTML_MODULES}};
my @time     = qw(hour day week year);

# other files to include
my @MORE     = qw(make_html.gz Makefile.gz sample.conf.gz);

sub insert_links($);

foreach my $time (@time) {
    my $file = "$path/$time.html";
    print "generating `$file'\n";
    open HTML, '>', $file or die "can't open `$file': $!";

    my $time2 = $time . "ly";
    $time2 =~ s/yly$/ily/;

    print HTML <<"EOF";
<!DOCTYPE html>
<html>
  <head>
    <title>$time2 statistics</title>
    <meta http-equiv="refresh" content="150; URL=$time.html">
    <meta charset="utf-8">
    <style>
       div.timespans { background-color: lightgray; padding: 0.5em; font-family: sans-serif; font-size: 80%; }
       body { margin: 0; background-color: #f3f3f3; font-family: serif; }
       footer { text-align: right; background-color: lightgray; padding: 0.5em; font-style: italic; }
       img { margin: 3px; }
    </style>
  </head>
  <body>
EOF
    ;

    insert_links($time);

    print HTML "    <div id=\"charts\">\n";
    foreach my $rrd (@rrd) {
	print HTML "      <img src=\"$rrd-$time.png\" alt=\"$rrd (last $time)\" align=\"top\">\n";
    }
    print HTML "    </div>\n";

    insert_links($time);

    print HTML <<"EOF";
    <footer>
      powered by <a href="https://github.com/mmitch/rrd">mitch’s rrd scripts</a>
    </footer>
  </body>
</html>
EOF
    ;

    close HTML or  die "can't close `$file': $!";
}



sub insert_links($)
{
    my $time = shift;
    my $bar = 0;
    print HTML "    <div class=\"timespans\">[";
    foreach my $linktime (@time) {
	if ($bar) {
	    print HTML "|";
	} else {
	    $bar = 1;
	}
	if ($linktime eq $time) {
	    print HTML " $linktime ";
	} else {
	    print HTML " <a href=\"$linktime.html\">$linktime</a> ";
	}
    }
    print HTML "]</div>\n";
}
