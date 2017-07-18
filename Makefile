all:
	./make_html.pl

dump-all:
	for RRD in *.rrd; do rrdtool dump $$RRD $$RRD.dump.xml; done
