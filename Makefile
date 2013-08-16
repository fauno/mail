# Where the config files are stored
ETC?=/etc
BUNDLE?=--path=vendor

TEMPLATES=$(shell find etc/ -name "*.mustache")
FILES=$(patsubst %.mustache,%,$(TEMPLATES))

bundle:
	bundle install $(BUNDLE)

$(FILES):
	bundle exec mustache mail.yml $@.mustache >$@

all: $(FILES)

clean:
	rm -rf $(FILES)

install: all
	rsync -av --no-owner --no-group etc/ $(ETC)/
	# TODO set correct permissions here
