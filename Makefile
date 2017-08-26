PERL_SOURCES_ALL  := $(wildcard *.pl)
PERL_SOURCES_SKIP := fritz.pl # no need for complete build & install of Net::Fritz in Travis CI build
PERL_SOURCES      := $(filter-out $(PERL_SOURCES_SKIP), $(PERL_SOURCES_ALL))
BASH_SOURCES      := $(wildcard *.sh)

all:
	./make_html.pl

dump-all:
	for RRD in *.rrd; do rrdtool dump $$RRD $$RRD.dump.xml; done

clean:
	rm -f *~ 

test: test-perl test-bash

travis-install-deps: travis-install-perl-deps

travis-install-perl-deps:
	@grep ^use $(PERL_SOURCES) | awk '{print $$2}' | sed 's/;$$//' | egrep -v '^(strict|warnings)$$' | sort | uniq | while read MOD; do perl -Itest/ -M"$$MOD" -e '1;' 2>/dev/null || echo "$$MOD" ; done | cpanm --skip-satisfied

test-perl:
	@for FILE in $(PERL_SOURCES); do perl -Itest/ -c "$$FILE" || exit 1; done

test-bash:
	@for FILE in $(BASH_SOURCES); do bash -n "$$FILE" && echo "$$FILE syntax OK" || exit 1; done
