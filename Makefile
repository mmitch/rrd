TARGET = /home/mitch/pub/rrd
STATICFILES = Makefile sample.conf make_html.pl

all:
	rm -f $(TARGET)/*.gz
	for I in *.pl $(STATICFILES); do \
		J=`echo $$I|sed s/.pl$$//`; \
		gzip < $$I > $(TARGET)/$$J.gz; \
	done
	./make_html.pl