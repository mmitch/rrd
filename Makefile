# $Id: Makefile,v 1.2 2005-11-13 15:44:28 mitch Exp $

TARGET = /home/mitch/pub/rrd
STATICFILES = Makefile sample.conf make_html.pl

all:
	rm -f $(TARGET)/*.gz
	for I in *.pl $(STATICFILES); do \
		J=`echo $$I|sed s/.pl$$//`; \
		gzip < $$I > $(TARGET)/$$J.gz; \
	done
	./make_html.pl