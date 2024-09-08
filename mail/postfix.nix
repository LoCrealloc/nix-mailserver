{
  pkgs,
  config,
  env,
  lib,
  ...
}:
let
  accounts-cf = pkgs.writeText "accounts.cf" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = select 1 as found from accounts where username = '%u' and domain = '%d' and enabled = true LIMIT 1;	
    	'';
  aliases-cf = pkgs.writeText "aliases.cf" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = select concat(destination_username, '@', destination_domain) as destinations from aliases where source_username = '%u' and source_domain = '%d' and enabled = true;
    	'';

  domains-cf = pkgs.writeText "domains" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = SELECT domain FROM domains WHERE domain='%s';
    	'';

  recipient-access-cf = pkgs.writeText "recipient-access.cf" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = select checkSendonly('%u', '%d') as access;
    	'';

  sender-login-maps-cf = pkgs.writeText "sender-login-maps.cf" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = select concat(username, '@', domain) as "owns" from accounts where username = '%u' AND domain = '%d' and enabled = true union select concat(destination_username, '@', destination_domain) AS "owns" from aliases where source_username = '%u' and source_domain = '%d' and enabled = true;
    	'';
  tls-policy-cf = pkgs.writeText "tls-policy.cf" ''
    user = vmail
    hosts = unix:/run/postgresql
    dbname = vmail
    query = SELECT policy, params FROM tlspolicies WHERE domain = '%s';
    	'';

  without-ptr = pkgs.writeText "without-ptr.db" '''';

  submission_header_cleanup = pkgs.writeText "submission_header_cleanup" ''
    /^Received:/            IGNORE
    /^X-Originating-IP:/    IGNORE
    /^X-Mailer:/            IGNORE
    /^User-Agent:/          IGNORE
    	'';
in
{

  services.postfix = {
    enable = true;

    # vertrauenswürdige Netzwerke
    networks = [
      "127.0.0.0/8"
      "[::ffff:127.0.0.0]/104"
      "[::1]/128"
    ];

    hostname = config.networking.fqdn;

    config = {
      inet_interfaces = "127.0.0.1, ::1, ${env.ip.v4}, ${env.ip.v6}, ${
        builtins.elemAt (lib.strings.splitString "/" env.wg.ip) 0
      }";

      maximal_queue_lifetime = "1h";
      bounce_queue_lifetime = "1h";
      maximal_backoff_time = "15m";
      minimal_backoff_time = "5m";
      queue_run_delay = "5m";

      # generated 2024-08-10, Mozilla Guideline v5.7, Postfix 3.9.0, OpenSSL 3.0.14, intermediate configuration
      # https://ssl-config.mozilla.org/#server=postfix&version=3.9.0&config=intermediate&openssl=3.0.14&guideline=5.7
      smtpd_tls_security_level = "may";
      smtpd_tls_auth_only = "yes";
      smtpd_tls_cert_file = "${config.security.acme.certs.mail.directory}/fullchain.pem";
      smtpd_tls_key_file = "${config.security.acme.certs.mail.directory}/key.pem";
      smtpd_tls_mandatory_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
      smtpd_tls_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
      smtpd_tls_mandatory_ciphers = "medium";

      smtp_tls_security_level = "dane";
      smtp_dns_support_level = "dnssec";
      smtp_tls_policy_maps = "proxy:pgsql:${tls-policy-cf}";
      smtp_tls_session_cache_database = "btree:$data_directory/smtp_scache";
      smtp_tls_ciphers = "medium";

      tls_medium_cipherlist = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305";
      tls_preempt_cipherlist = "no";

      virtual_transport = "lmtp:unix:private/dovecot-lmtp";

      smtpd_milters = "inet:localhost:11332"; # TODO
      non_smtpd_milters = "inet:localhost:11332"; # TODO
      milter_protocol = "6";
      milter_mail_macros = "i {mail_addr} {client_addr} {client_name} {auth_authen}";
      milter_default_action = "accept";

      # Wichtig, um kein Open Relay zu werden
      smtpd_relay_restrictions = [
        "reject_non_fqdn_recipient"
        "reject_unknown_recipient_domain"
        "permit_mynetworks"
        "reject_unauth_destination"
      ];

      smtpd_recipient_restrictions = "check_recipient_access proxy:pgsql:${recipient-access-cf}";

      smtpd_client_restrictions = [
        "permit_mynetworks"
        #"check_client_access hash:${without-ptr}"
        "reject_unknown_client_hostname"
      ];

      smtpd_helo_required = "yes";
      smtpd_helo_restrictions = [
        "permit_mynetworks"
        "reject_invalid_helo_hostname"
        "reject_non_fqdn_helo_hostname"
        "reject_unknown_helo_hostname"
      ];

      # Clients blockieren, wenn sie versuchen zu früh zu senden
      smtpd_data_restrictions = "reject_unauth_pipelining";

      mua_relay_restrictions = "reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_mynetworks,permit_sasl_authenticated,reject";
      mua_sender_restrictions = "permit_mynetworks,reject_non_fqdn_sender,reject_sender_login_mismatch,permit_sasl_authenticated,reject";
      mua_client_restrictions = "permit_mynetworks,permit_sasl_authenticated,reject";

      proxy_read_maps = [
        "proxy:pgsql:${aliases-cf}"
        "proxy:pgsql:${accounts-cf}"
        "proxy:pgsql:${domains-cf}"
        "proxy:pgsql:${recipient-access-cf}"
        "proxy:pgsql:${sender-login-maps-cf}"
        "proxy:pgsql:${tls-policy-cf}"
      ];

      virtual_alias_maps = "proxy:pgsql:${aliases-cf}";
      virtual_mailbox_maps = "proxy:pgsql:${accounts-cf}";
      virtual_mailbox_domains = "proxy:pgsql:${domains-cf}";
      local_recipient_maps = "$virtual_mailbox_maps";

      ### Maximale Größe der gesamten Mailbox (soll von Dovecot festgelegt werden, 0 = unbegrenzt)
      mailbox_size_limit = "0";

      ### Maximale Größe eingehender E-Mails in Bytes (50 MB)
      message_size_limit = "52428800";

      ### Keine System-Benachrichtigung für Benutzer bei neuer E-Mail
      biff = false;

      ### Nutzer müssen immer volle E-Mail Adresse angeben - nicht nur Hostname
      append_dot_mydomain = false;

      ### Trenn-Zeichen für "Address Tagging"
      recipient_delimiter = "+";

      ### Keine Rückschlüsse auf benutzte Mailadressen zulassen
      disable_vrfy_command = true;
    };

    enableSmtp = false; # Manually

    masterConfig = {
      smtp_inet = {
        name = "smtp";
        type = "inet";
        private = false;
        chroot = true;
        command = "smtpd";
        args = [ "-o smtpd_sasl_auth_enable=no" ];
      };

      smtp = {
        type = "unix";
        chroot = true;
        command = "smtp";
      };

      relay = {
        chroot = true;
        command = "smtp";
      };

      smtps = {
        type = "inet";
        private = false;
        chroot = true;
        command = "smtpd";
        args = [
          "-o syslog_name=postfix/smtps"
          "-o smtpd_tls_wrappermode=yes"
          "-o smtpd_tls_security_level=encrypt"
          "-o smtpd_sasl_auth_enable=yes"
          "-o smtpd_sasl_type=dovecot"
          "-o smtpd_sasl_path=private/auth"
          "-o smtpd_sasl_security_options=noanonymous"
          "-o smtpd_client_restrictions=$mua_client_restrictions"
          "-o smtpd_sender_restrictions=$mua_sender_restrictions"
          "-o smtpd_relay_restrictions=$mua_relay_restrictions"
          "-o milter_macro_daemon_name=ORIGINATING"
          "-o smtpd_sender_login_maps=proxy:pgsql:${sender-login-maps-cf}"
          "-o smtpd_helo_required=no"
          "-o smtpd_helo_restrictions="
          "-o cleanup_service_name=submission-header-cleanup"
        ];
      };
      submission-header-cleanup = {
        type = "unix";
        private = false;
        chroot = false;
        maxproc = 0;
        command = "cleanup";
        args = [ "-o header_checks=regexp:${submission_header_cleanup}" ];
      };
    };
  };
}
