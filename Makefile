# $Id: Makefile,v 1.1 2003-07-30 22:24:05 mitch Exp $

all:
	rm -f /home/mitch/pub/rrd/*.gz
	for I in *.pl; do \
		J=`echo $$I|sed s/.pl$$//`; \
		gzip < $$I > /home/mitch/pub/rrd/$$J.gz; \
	done
	./make_html.pl