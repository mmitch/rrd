#!/usr/bin/perl -w
# $Id: make_html.pl,v 1.4 2003-08-02 11:55:02 mitch Exp $
#
# Generate HTML pages for rrd stats
#
use strict;
use warnings;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $path     = $conf{OUTPATH};
my @rrd      = @{$conf{MAKEHTML_MODULES}};
my @time     = qw(hour day week year);


sub insert_links($);


foreach my $time (@time) {
    my $file = "$path/$time.html";
    print "generating `$file'\n";
    open HTML, '>', $file or die "can't open `$file': $!";

    my $time2 = $time . "ly";
    $time2 =~ s/yly$/ily/;

    print HTML "<html><head><title>$time2 statistics</title>";
    print HTML "<meta http-equiv=\"refresh\" content=\"150; URL=$time.html\">";
    print HTML "</head><body>";

    insert_links($time);

    foreach my $rrd (@rrd) {
	print HTML "<img src=\"$rrd-$time.png\" alt=\"$rrd (last $time)\">";
    }

    print HTML "<hr>";

    insert_links($time);

    print HTML "<p><small>Get the scripts here:";

    opendir SCRIPTS, $path or die "can't opendir `$path': $!";
    foreach my $script (sort grep /\.gz$/, readdir SCRIPTS) {
	    print HTML " <a href=\"$script\">$script</a>";
    }
    closedir SCRIPTS or die "can't closedir `$path': $!";

    print HTML "</p></body></html>";

    close HTML or  die "can't close `$file': $!";
}



sub insert_links($)
{
    my $time = shift;
    my $bar = 0;
    print HTML "<p>[";
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
    print HTML "]</p><hr>";
}
