# NixOS mailserver

This is the configuration for my NixOS mailserver, runnning on Hetzner Cloud.

## Features

- [ x ] Postfix for SMTP/SUBMISSION
- [ x ] Dovecot for IMAP
- [ x ] Rspamd for spam detection & DKIM signing
  - [ x ] automated updating of the DKIM DNS record via Hetzner DNS API
  - [ x ] Redis as cache
- [ x ] Unbound DNS for local DNS resolution
- [ x ] ACME for automated certificate renewing
- [ x ] Postgresql as a database for both postfix and dovecot
- [ x ] Thunderbird autoconfig
- [ x ] Wireguard
- [ ] LDAP integration
