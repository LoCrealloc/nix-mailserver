{
  config,
  pkgs,
  env,
  ...
}:
let
  selector = "2024";
in
{
  services.rspamd = {
    enable = true;

    workers = {
      controller = {
        enable = true;
        type = "controller";
        count = 1;
        bindSockets = [
          {
            socket = "/run/rspamd/rspamd.sock";
            mode = "0660";
            owner = "${config.services.rspamd.user}";
            group = "${config.services.rspamd.group}";
          }
        ];
      };
      proxy = {
        enable = true;
        type = "rspamd_proxy";
        bindSockets = [ "localhost:11332" ];
      };
    };

    locals =
      let
        dkim_config = ''
          path = "/var/lib/rspamd/dkim/${selector}.key";
          selector = "2020";

          ### Enable DKIM signing for alias sender addresses
          allow_username_mismatch = true;
        '';

        milter_config = ''
          milter = yes;
          timeout = 120s;
          upstream "local" {
          	default = yes;
          	self_scan = yes;
          }
          max_retries = 5;
          discard_on_reject = false;
          quarantine_on_reject = false;
          spam_header = "X-Spam";
          reject_message = "Spam message rejected";
        '';
      in
      {
        "milter_headers.conf".text = ''
          use = ["x-spamd-bar", "x-spam-level", "authentication-results"];
          authenticated_headers = ["authentication-results"];
        '';
        "classifier-bayes.conf".text = ''
          backend = "redis";
        '';
        "redis.conf".text = ''
          servers = ${config.services.redis.servers.rspamd.unixSocket};
        '';
        "dkim_signing.conf".text = dkim_config;
        "arc.conf".text = dkim_config;
        "worker-controller.inc".source = config.sops.secrets.rspamd_hash.path;
        "worker-proxy.inc".text = milter_config;
      };

    overrides = {
      "classifier-bayes.conf".text = ''
        autolearn = true;
      '';
    };
  };

  sops.secrets = {
    "hetzner_api" = {
      sopsFile = ../secrets/acme_hetzner;
      format = "binary";
      group = "rspamd";
      mode = "0440";
    };
    "rspamd_hash" = {
      sopsFile = ../secrets/rspamd_hash;
      format = "binary";
      group = "rspamd";
      mode = "0440";
    };
  };

  systemd.services.rspamd.preStart =
    let
      path = "/var/lib/rspamd/dkim";

      # Script which uses the Hetzner DNS API to automatically update the DKIM DNS record
      dkim_update = pkgs.writeShellApplication {
        name = "dkim_update";
        runtimeInputs = with pkgs; [
          jq
          curl
        ];
        text = (builtins.readFile ./dkim_update.sh);
      };
    in
    ''

      if [ -f ${path}/${selector}.txt ]; then
      	exit
      fi

      mkdir -p ${path}

      ${pkgs.rspamd}/bin/rspamadm dkim_keygen -b 2048 -s ${selector} -k ${path}/${selector}.key > ${path}/${selector}.txt
      chown -R ${config.services.rspamd.user}:${config.services.rspamd.group} ${path}
      chmod 440 ${path}/*

      # I am no sed wizard. Source: https://stackoverflow.com/a/5983479
      ${dkim_update}/bin/dkim_update \
      	"${selector}._domainkey" \
      	"$(${pkgs.gnused}/bin/sed -n '/(/,/)/{:a; $!N; /)/!{$!ba}; s/.*(\([^)]*\)).*/\1/p}' ${path}/${selector}.txt | tr -d [:space:])" \
      	"$(sed -n s/HETZNER_API_KEY=//p ${config.sops.secrets.hetzner_api.path})" \
      	${env.domain}
    '';
}
