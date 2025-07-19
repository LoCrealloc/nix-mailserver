{
  config,
  env,
  pkgs,
  ...
}:
let
  mail_user = "vmail";
  mail_group = "vmail";

  sql-file = pkgs.writeText "dovecot-sql" ''
    		driver=pgsql
        connect = "host=/run/postgresql dbname=vmail user=vmail"

        password_query = SELECT username AS user, domain, password FROM accounts WHERE username = '%Ln' AND domain = '%Ld' and enabled = true;
        user_query = SELECT concat('*:storage=', quota, 'M') AS quota_rule FROM accounts WHERE username = '%Ln' AND domain = '%Ld' AND sendonly = false;
        iterate_query = SELECT username, domain FROM accounts where sendonly = false;
        	'';

  spam-global = pkgs.writeText "spam-global.sieve" (builtins.readFile ./sieves/spam-global.sieve);

  postfix_queue = config.services.postfix.config.queue_directory;
in
{
  environment.systemPackages = with pkgs; [ dovecot_pigeonhole ];

  services.dovecot2 = {
    enable = true;

    enablePAM = false;

    enableDHE = true;
    enableImap = true;
    enableLmtp = true;

    protocols = [ "sieve" ];

    mailUser = mail_user;
    mailGroup = mail_group;

    sslServerCert = "${config.security.acme.certs.mail.directory}/fullchain.pem";
    sslServerKey = "${config.security.acme.certs.mail.directory}/key.pem";

    mailLocation = "maildir:~/mail:LAYOUT=fs";

    mailboxes = {
      Spam = {
        auto = "subscribe";
        specialUse = "Junk";
      };

      Trash = {
        auto = "subscribe";
        specialUse = "Trash";
      };

      Drafts = {
        auto = "subscribe";
        specialUse = "Drafts";
      };

      Sent = {
        auto = "subscribe";
        specialUse = "Sent";
      };
    };

    sieve = {
      plugins = [
        "sieve_imapsieve"
        "sieve_extprograms"
      ];
      globalExtensions = [ "vnd.dovecot.pipe" ];
      extensions = [ "vnd.dovecot.environment" ];
    };

    pluginSettings = {
      sieve_before = "/var/vmail/spam-global.sieve";
      sieve = "file:/var/vmail/sieve/%d/%n/scripts;active=/var/vmail/sieve/%d/%n/active-script.sieve"; # TODO

      quota = "maildir:User quota";
      quota_exceeded_message = "Benutzer %u hat das Speichervolumen überschritten. / User %u has exhausted allowed storage space.";
    };

    imapsieve = {
      mailbox = [
        {
          name = "Spam";
          causes = [ "COPY" ];
          before = ./sieves/learn-spam.sieve;
        }
        {
          name = "*";
          causes = [ "COPY" ];
          from = "Spam";
          before = ./sieves/learn-ham.sieve;
        }
      ];
    };

    extraConfig = ''
      ssl = required
      ssl_cipher_list = EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA256:EECDH:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA128-SHA:AES128-SHA
      ssl_prefer_server_ciphers = yes

      recipient_delimiter = +

      service imap-login {
      	inet_listener imap {
      	port = 143
      	}
      }

      service managesieve-login {
      	inet_listener sieve {
      	port = 4190
      	}
      }

      service lmtp {
      	unix_listener ${postfix_queue}/private/dovecot-lmtp {
      		mode = 0660
      		group = postfix
      		user = postfix
      	}
      	user = vmail
      }

      service auth {
      	user = ${config.services.dovecot2.user}

      	unix_listener ${postfix_queue}/private/auth {
      		mode = 0660
      		user = postfix
      		group = postfix
      	}

      	unix_listener auth-userdb {
      		mode = 0660
      		user = ${mail_user}
      		group = ${mail_group}
      	}
      }

      protocol imap {
      	mail_plugins = $mail_plugins quota imap_quota imap_sieve
      	mail_max_userip_connections = 20
      	imap_idle_notify_interval = 29 mins
      }

      protocol lmtp {
      	postmaster_address = postmaster@${env.domain}
      	mail_plugins = $mail_plugins sieve notify push_notification
      }

      auth_username_format = %Lu

      passdb {
      	driver = sql
      	args = ${sql-file}
      }

      userdb {
      	driver = sql
      	args = ${sql-file}
      }

      mail_home = /var/vmail/mailboxes/%d/%n
    '';
  };
  systemd.services.dovecot.preStart = ''
    mkdir -p /var/vmail

    cp ${spam-global} /var/vmail/spam-global.sieve

    chown -R ${mail_user}:${mail_group} /var/vmail
  '';
}
