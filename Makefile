default: all
# Where the config files are stored
ETC ?= /etc
# Security level
SECURITY ?= high
# Bundler flags
BUNDLE ?= --path=vendor

# The domain
# TODO define variables from mail.yml
DOMAIN = $(shell grep "^domain" mail.yml | cut -d" " -f2 | tr -d "'")
MAILDIR = $(shell grep "^mail:" mail.yml | cut -d" " -f2 | tr -d "'")

# The template files
TEMPLATES = $(shell find etc/ -name "*.mustache")
# The files
FILES = $(patsubst %.mustache,%,$(TEMPLATES))

# Do the files
all: $(FILES)

# Cleanup
clean:
	rm -rf $(FILES)

# Install gems
bundle:
	bundle install $(BUNDLE)

# Generate files
$(FILES):
	bundle exec mustache mail.yml $@.mustache >$@

# Create directories
ssl-dirs:
	mkdir -p etc/ssl/private
	mkdir -p etc/ssl/certs

# Generates an OpenDKIM key and DNS record
opendkim: ssl-dirs etc/opendkim/opendkim.conf
	test -f etc/ssl/private/$(DOMAIN).dkim || \
	opendkim-genkey -s mail -v && \
	mv mail.private etc/ssl/private/$(DOMAIN).dkim && \
	mv mail.txt dns/opendkim.txt

# Generates the private key, requires GnuTLS installed
ssl-keys: ssl-dirs
	test -f etc/ssl/private/$(DOMAIN).key || \
	certtool --generate-privkey \
	         --outfile=etc/ssl/private/$(DOMAIN).key \
	         --sec-param=$(SECURITY)
	for dh in 512 1024 2048; do \
	  test -f etc/ssl/private/$$dh.dh || \
	  certtool --generate-dh \
	           --outfile=etc/ssl/private/$$dh.dh \
	           --bits=$$dh ; \
	done

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

# Create mail user and storage dirs
install-vmail:
	getent passwd vmail || \
	useradd --comment 'Virtual Mail' \
	        --system \
	        --shell /bin/false \
	        --user-group \
	        --create-home \
	        --home-dir '$(MAILDIR)' \
	        vmail

# Install to system
install:
	rsync -av --no-owner --no-group --exclude="*.mustache" etc/ $(ETC)/
	# TODO set correct permissions here
