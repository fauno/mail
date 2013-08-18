# Where the config files are stored
ETC?=/etc
BUNDLE?=--path=vendor
DOMAIN=$(shell grep "^domain" mail.yml | cut -d" " -f2 | tr -d "'")

SECURITY?=high

TEMPLATES=$(shell find etc/ -name "*.mustache")
FILES=$(patsubst %.mustache,%,$(TEMPLATES))

bundle:
	bundle install $(BUNDLE)

$(FILES):
	bundle exec mustache mail.yml $@.mustache >$@

# Create directories
ssl-dirs:
	mkdir -p etc/ssl/private
	mkdir -p etc/ssl/certs

# Generates an OpenDKIM key and DNS record
opendkim: ssl-dirs
	opendkim-genkey -s mail -v && \
	mv mail.private etc/ssl/private/$(DOMAIN).dkim && \
	mv mail.txt dns/opendkim.txt

# Generates the private key, requires GnuTLS installed
ssl-keys: ssl-dirs
	test -f etc/ssl/private/$(DOMAIN).key || \
	certtool --generate-privkey \
	         --outfile=etc/ssl/private/$(DOMAIN).key \
	         --sec-param=$(SECURITY)
# I only needed this on a ircd
	test -f etc/ssl/private/$(DOMAIN).dh || \
	certtool --generate-dh \
	         --outfile=etc/ssl/private/$(DOMAIN).dh \
					 --bits=2048

# Generates a self-signed certificate
# This is enough for a mail server and if you don't want to pay a lot of
# USD for a few thousand bits.  It's not for user agents trying to
# verify your certs unaware of this situation
ssl-self-signed-cert: ssl-keys
	test -f etc/ssl/certs/$(DOMAIN).crt || \
	certtool --generate-self-signed \
	         --outfile=etc/ssl/certs/$(DOMAIN).crt \
	         --load-privkey=etc/ssl/private/$(DOMAIN).key \
	         --template=etc/certs.cfg

# First step on the process of getting a certificate, generate a
# request.  This file must be uploaded to the CA.  You can get one for
# free at cacert.org or starssl.com (though they ask for personal info.)
ssl-request-cert: ssl-keys
	test -f etc/ssl/private/$(DOMAIN).csr || \
	certtool --generate-request \
	         --outfile=etc/ssl/private/$(DOMAIN).csr \
	         --load-privkey=etc/ssl/private/$(DOMAIN).key \
	         --template=etc/certs.cfg

all: $(FILES)

clean:
	rm -rf $(FILES)

install: all
	rsync -av --no-owner --no-group etc/ $(ETC)/
	# TODO set correct permissions here
