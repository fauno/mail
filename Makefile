default: all

# Domains this node will be serving, one per line without comments, the
# first domain is assumed to be the main domain
DOMAIN_LIST = $(PWD)/domains
# How you call the inhabitants of the node
PEOPLE = pirates
# Base group of the PEOPLE
GROUP = ship
# Hostname
HOST = $(shell hostname)
# The main domain
FQDN = $(shell head -n1 $(DOMAIN_LIST))

# Where the config files are stored
ETC ?= /etc
# Security level for GnuTLS
SECURITY ?= high
# Bundler flags
BUNDLE ?= --path=vendor

# Diffie-Hellman bits
DH_BITS = 512 1024 2048

# List of domains extracted from the domain file
DOMAINS = $(shell cat $(DOMAIN_LIST) )

# The template files
TEMPLATES = $(shell find etc/ -name "*.mustache")
# The files
FILES = $(patsubst %.mustache,%,$(TEMPLATES))

# Do the files
all: PHONY mail.yml $(FILES) ssl-self-signed-certs

make-tmp:
	mkdir -p tmp

# Create the mail.yml file for mustache to work
mail.yml:
	echo "---" >mail.yml
	echo "hostname: $(HOST)" >>mail.yml
	echo "fqdn: $(FQDN)" >>mail.yml
	echo "domains:" >>mail.yml
	sed  "s/^/    - /" $(DOMAIN_LIST) >>mail.yml
	echo "people: $(PEOPLE)" >>mail.yml
	echo "group: $(GROUP)" >>mail.yml
	echo "---" >>mail.yml

# Cleanup
clean: PHONY
	rm -rf $(FILES) mail.yml etc/ssl tmp

# Install gems
bundle: PHONY
	bundle install $(BUNDLE)

# Generate files
$(FILES): | bundle
	bundle exec mustache mail.yml $@.mustache >$@

create-groups: PHONY
	# a group for the inhabitants
	groupadd $(GROUP)
	# a group for private keys
	groupadd --system keys

# Create directories
ssl-dirs: PHONY
	# setgid set for private keys
	install -d -m 2750 etc/ssl/private
	install -d -m 755 etc/ssl/certs

# Generates an OpenDKIM key and DNS record
opendkim: ssl-dirs etc/opendkim/opendkim.conf
	test -f etc/ssl/private/$(FQDN).dkim || \
	opendkim-genkey -s mail -v && \
	mv mail.private etc/ssl/private/$(FQDN).dkim && \
	mv mail.txt dns/opendkim.txt

# Generate DH params, needed by Perfect Forward Secrecy cyphersuites
# Some notes:
# * Read this for DH in postfix: http://postfix.1071664.n5.nabble.com/Diffie-Hellman-parameters-td63096.html
# * With certtool 3.3.4 creation of dh params for 4096 bits fail
DIFFIE_HELLMAN_PARAMS = $(addsuffix .dh,$(addprefix etc/ssl/private/,$(DH_BITS)))
$(DIFFIE_HELLMAN_PARAMS): etc/ssl/private/%.dh: | ssl-dirs
	certtool --generate-dh-params \
	         --outfile=etc/ssl/private/$*.dh \
	         --bits=$*

# Generate all dh params
ssl-dh-params: $(DIFFIE_HELLMAN_PARAMS)

SSL_TEMPLATES = $(addsuffix .cfg,$(addprefix tmp/,$(DOMAINS)))
$(SSL_TEMPLATES): tmp/%.cfg: mail.yml | bundle make-tmp
	sed "s,fqdn: .*,fqdn: $*," mail.yml | bundle exec mustache - etc/certs.cfg.mustache >$@

# Generates the private key for a domain, requires GnuTLS installed
SSL_PRIVATE_KEYS = $(addsuffix .key,$(addprefix etc/ssl/private/,$(DOMAINS)))
$(SSL_PRIVATE_KEYS): | ssl-dirs
	certtool --generate-privkey \
	         --outfile=$@ \
	         --sec-param=$(SECURITY)

# Generates all private keys
ssl-private-keys: $(SSL_PRIVATE_KEYS)

# Generates a self-signed certificate
# This is enough for a mail server and if you don't want to pay a lot of
# USD for a few thousand bits.  It's not for user agents trying to
# verify your certs unaware of this situation

SSL_SELF_SIGNED_CERTS = $(addsuffix .crt,$(addprefix etc/ssl/certs/,$(DOMAINS)))
$(SSL_SELF_SIGNED_CERTS): etc/ssl/certs/%.crt: etc/ssl/private/%.key tmp/%.cfg
	certtool --generate-self-signed \
	         --outfile=$@ \
	         --load-privkey=$< \
	         --template=tmp/$*.cfg

# Generates all self signed certs
ssl-self-signed-certs: $(SSL_SELF_SIGNED_CERTS)

# First step on the process of getting a certificate, generate a
# request.  This file must be uploaded to the CA.  You can get one for
# free at cacert.org or starssl.com (though they ask for personal info.)
SSL_REQUEST_CERTS = $(addsuffix .csr,$(addprefix etc/ssl/private/,$(DOMAINS)))
$(SSL_REQUEST_CERTS): etc/ssl/private/%.csr: etc/ssl/private/%.key tmp/%.cfg
	certtool --generate-request \
	         --outfile=$@ \
	         --load-privkey=$< \
	         --template=tmp/$*.cfg

# Generate all SSL requests
ssl-request-certs: $(SSL_REQUEST_CERTS)

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

PHONY:
.PHONY: PHONY
