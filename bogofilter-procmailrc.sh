#!/bin/bash
#
# bogofilter statistics gathering script
#
# Copyright (C) 2007, 2011  Christian Garbs <mitch@cgarbs.de>
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

DATAFILE=/home/mitch/rrd/bogofilter.rrd
LINE=$(grep ^X-Bogosity: | head -n 1)
[ "$LINE" ] || exit
case ${LINE:12} in
	Ham*)
		rrdupdate $DATAFILE N:1:0:0
		;;
	Unsure*)
		rrdupdate $DATAFILE N:0:1:0
		;;
	Spam*)
		rrdupdate $DATAFILE N:0:0:1
		;;
esac
sleep 1
