my rrd statistic scripts
========================

This is a collection of scripts that draw some nice graphs with
information about your system: cpu load, network load, free disk space
and so on.

Various scripts are included.  Most will be useful for everyone, but
some are very special for my personal needs.  You probably won't find
them useful.

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
