A mailserver configuration.  This is a working mailserver turn into
template.


## Goals

Provide a quick and secure mailserver setup meant for small communities.
Stop thinking about one big mail service!

## Requirements

postfix, ejabberd, dovecot, cyrus-sasl, openldap

## TODO

* Scripts to roll over the config!

### Services

* Roundcube
* [Encrypted storage](https://grepular.com/Automatically_Encrypting_all_Incoming_Email "Automatically Encrypting all Incoming Email - grepular.com")
* Prosody - smaller than ejabberd but as of v0.8 a pain for ldap
* PAM authentication - provide shells to users
* Other ldap-capable services
