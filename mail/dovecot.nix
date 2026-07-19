{
  config,
  env,
  pkgs,
  ...
}:
let
  mail_user = "vmail";
  mail_group = "vmail";

  spam-global = pkgs.writeText "spam-global.sieve" (builtins.readFile ./sieves/spam-global.sieve);

  postfix_queue = config.services.postfix.settings.main.queue_directory;
in
{
  environment.systemPackages = [ config.services.dovecot2.package.passthru.dovecot_pigeonhole ];

  services.dovecot2 = {
    enable = true;
    enablePAM = false;
    package = pkgs.dovecot;

    settings = {
      dovecot_config_version = config.services.dovecot2.package.version;
      dovecot_storage_version = config.services.dovecot2.package.version;

      mail_uid = mail_user;
      mail_gid = mail_group;

      ssl = "required";
      ssl_cipher_list = "EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA256:EECDH:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA128-SHA:AES128-SHA";

      recipient_delimiter = "+";

      auth_username_format = "%{user | lower}";

      mail_home = "/var/vmail/mailboxes/%{user|domain}/%{user|username}";
      mail_driver = "maildir";
      mail_path = "~/mail";
      mailbox_list_layout = "fs";

      ssl_server_cert_file = "${config.security.acme.certs.mail.directory}/fullchain.pem";
      ssl_server_key_file = "${config.security.acme.certs.mail.directory}/key.pem";

      sieve_plugins = [
        "sieve_imapsieve"
        "sieve_extprograms"
      ];

      sieve_extensions = [
        "vnd.dovecot.environment"
        "fileinto"
      ];
      sieve_global_extensions = [ "vnd.dovecot.pipe" ];

      "sieve_script before" = {
        path = "/var/vmail/spam-global.sieve";
      };

      "quota \"User quota\"" = { };
      quota_exceeded_message = "Benutzer %{user} hat das Speichervolumen überschritten. / User %{user} has exhausted allowed storage space.";

      "imapsieve_from Spam" = {
        "sieve_script ham" = {
          type = "before";
          cause = "copy";
          path = ./sieves/learn-ham.sieve;
        };
      };

      "mailbox spam" = {
        name = "Spam";
        auto = "subscribe";
        special_use = "\\Junk";

        "sieve_script spam" = {
          type = "before";
          cause = "copy";
          path = ./sieves/learn-spam.sieve;
        };
      };

      "mailbox trash" = {
        name = "Trash";
        auto = "subscribe";
        special_use = "\\Trash";
      };

      "mailbox drafts" = {
        name = "Drafts";
        auto = "subscribe";
        special_use = "\\Drafts";
      };

      "mailbox sent" = {
        name = "Sent";
        auto = "subscribe";
        special_use = "\\Sent";
      };

      service = [
        {
          _section.name = "imap-login";
          "inet_listener imap" = {
            port = 143;
          };
        }
        {
          _section.name = "managesieve-login";
          "inet_listener sieve" = {
            port = 4190;
          };
        }
        {
          _section.name = "lmtp";
          "unix_listener ${postfix_queue}/private/dovecot-lmtp" = {
            mode = 0660;
            group = "postfix";
            user = "postfix";
          };
          user = "vmail";
        }
        {
          _section.name = "auth";
          user = config.services.dovecot2.settings.default_internal_user;

          "unix_listener ${postfix_queue}/private/auth" = {
            mode = 0660;
            user = "postfix";
            group = "postfix";
          };

          "unix_listener auth-userdb" = {
            mode = 0660;
            user = mail_user;
            group = mail_group;
          };
        }
      ];

      protocols = {
        lmtp = true;
        imap = true;
      };

      "protocol imap" = {
        mail_plugins = [
          "quota"
          "imap_quota"
          "imap_sieve"
        ];
        mail_max_userip_connections = 20;
        imap_idle_notify_interval = "29 mins";
      };

      "protocol lmtp" = {
        postmaster_address = "postmaster@${env.domain}";
        mail_plugins = [
          "sieve"
          "notify"
          "push_notification"
        ];
      };

      sql_driver = "pgsql";

      "pgsql /run/postgresql" = {
        parameters = {
          user = "vmail";
          dbname = "vmail";
        };
      };

      "passdb sql" = {
        query = "SELECT username AS user, domain, password FROM accounts WHERE username = '%{user | username}' AND domain = '%{user | domain}' and enabled = true";
      };

      "userdb sql" = {
        query = "SELECT concat('*:storage=', quota, 'M') AS quota_rule FROM accounts WHERE username = '%{user | username}' AND domain = '%{user | domain}' AND sendonly = false";
        iterate_query = "SELECT username, domain FROM accounts where sendonly = false";
      };
    };
  };

  systemd.services.dovecot.preStart = ''
    mkdir -p /var/vmail

    cp ${spam-global} /var/vmail/spam-global.sieve

    chown -R ${mail_user}:${mail_group} /var/vmail
  '';
}
