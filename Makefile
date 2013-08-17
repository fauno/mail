# Where the config files are stored
ETC?=/etc
BUNDLE?=--path=vendor
DOMAIN=$(shell grep "^domain" mail.yml | cut -d" " -f2 | tr -d "'")

TEMPLATES=$(shell find etc/ -name "*.mustache")
FILES=$(patsubst %.mustache,%,$(TEMPLATES))

bundle:
	bundle install $(BUNDLE)

$(FILES):
	bundle exec mustache mail.yml $@.mustache >$@

ssl-private:
	mkdir -p etc/ssl/private

opendkim: ssl-private
	opendkim-genkey -s mail -v && \
	mv mail.private etc/ssl/private/$(DOMAIN).dkim && \
	mv mail.txt dns/opendkim.txt

all: $(FILES)

clean:
	rm -rf $(FILES)

install: all
	rsync -av --no-owner --no-group etc/ $(ETC)/
	# TODO set correct permissions here
