my rrd statistic scripts
========================

[![Build status](https://github.com/mmitch/rrd/workflows/tests/badge.svg)](https://github.com/mmitch/rrd/actions?query=workflow%3Atests)
[![GPL 3+](https://img.shields.io/badge/license-GPL%203%2B-blue.svg)](http://www.gnu.org/licenses/gpl-3.0-standalone.html)

This is a collection of scripts that draw some nice graphs with
information about your system: cpu load, network load, free disk space
and so on.

Various scripts are included.  Most will be useful for everyone, but
some are very special for my personal needs.  You probably won't find
them useful.

The scripts are not designed to be deployed on a server farm with
hundreds of systems nor do they provide alerts if something goes
wrong - they are completely passive.  There are various other tools
for these kind of scenarios (but if you do look for a small and simple
solution for some local nomitoring and alerting, have a look at
https://github.com/mmitch/nomd).

dependencies
------------

For starters, you will need the `rrdtool` package, `bash` (any
`sh`-style shell might work, but currently it says `#!/usr/bin/bash`),
the `lockfile` program, `Perl` and the `RRDs` Perl module (not
available separately on CPAN, comes with the `rrdtool` package;
available as `librrds-perl` on Debian/Ubuntu).

Some modules will need other things as well.  You'll see it when
something breaks :-)

setup
-----

There is a bit of guesswork here, as most of my systems run these
scripts for over 10 years, so I have no recent experience with a fresh
setup :-/

1. copy `sample.conf` to `~/.rrd-conf.pl` and edit it to your needs
   - just ignore stuff for modules that you don't want to use
   - don't miss `$conf{MAKEHTML_MODULES}` at the end where you can
     include your selected modules into the generated HTML pages

2. edit `runall.sh` to only include the modules you need
   - the total script runtime should not exceed 5 minutes, so adjust
     `$RRD_WAIT` accordingly (Rationale: the script runtime should be
     somewhat stretched out over the 5 minute intervall in order not
     to cause big load spikes every 5 minutes.  If you don't mind
     that, just set `$RRD_WAIT` to `0`.)
   - don't get too near to 5 minutes or slightly higher system load
     will cause you to run into lockfile problems (see commit
     eb8e20052a for what the lockfile is about - you could also just
     remove it)
   - By default, `$DRAW_DETAILS` is set to `0` to decrease the load.
     Values will be logged every 5 minutes, but graphs will only be
     rendered every 30 minutes.  If you need more up-to-date graphs,
     set `$DRAW_DETAILS` to `1`.

3. run `make` once to generate your HTML pages

4. set up a cronjob that runs the `runall.sh` script every 5 minutes
   - all scripts run on a 5 minute interval base
   - all scripts autogenerate their RRD databases if they are missing

5. system load is the only thing that is tracked every minute, so you
   manually to set up a cronjob that runs every minute and executes
   this:

``` shell
rrdtool update PATH/TO/YOUR/load.rrd N:$( PROCS=`echo /proc/[0-9]*|wc -w|tr -d ' '`; read L1 L2 L3 DUMMY < /proc/loadavg ; echo ${L1}:${L2}:${L3}:${PROCS} )
```

Now wait for some time until some data has been gathered, then open
the generated HTML pages and enjoy your graphs.

license
-------

Copyright (C) 2003-2009, 2011, 2013, 2015-2018  Christian Garbs <mitch@cgarbs.de>  
Licensed under GNU GPL v3 or later.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
