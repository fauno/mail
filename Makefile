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

ssl-dirs:
	mkdir -p etc/ssl/private
	mkdir -p etc/ssl/certs

# Generates an OpenDKIM key and DNS record
opendkim: ssl-dirs
	opendkim-genkey -s mail -v && \
	mv mail.private etc/ssl/private/$(DOMAIN).dkim && \
	mv mail.txt dns/opendkim.txt

# Generates the private key, requires GnuTLS installed
ssl-key: ssl-dirs
	certtool --generate-privkey --outfile=etc/ssl/private/$(DOMAIN).key


certs: ssl-dirs
	

all: $(FILES)

clean:
	rm -rf $(FILES)

install: all
	rsync -av --no-owner --no-group etc/ $(ETC)/
	# TODO set correct permissions here
