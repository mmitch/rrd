#!/usr/bin/perl
# $Id: maild.pl,v 1.1 2003-05-03 18:00:56 mitch Exp $
use warnings;
use strict;

# parse mail log from exim

while (my $line = <>) {
    chomp $line;
    if ($line =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \S{6}-\S{6}-\S{2} <= \S+@\S+ U=(\S+) P=(\S+) S=(\d+)/) {
	my ($user, $process, $size) = ($1, $2, $3);
	if ($process eq "local-rmail") {
	    print "out: $size\n";
	} else {
	    print "in:  $size\n";
	}
    }
}
