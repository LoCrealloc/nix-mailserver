{
  config,
  pkgs,
  lib,
  ...
}:
let

  autoconfig = pkgs.writeTextDir "mail/config-v1.1.xml" (
    builtins.replaceStrings [ "DOMAINVAR" ] [ "${config.networking.domain}" ] (
      builtins.readFile ./autoconfig.xml
    )
  );

in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ]; # HTTPS

  users.users.nginx.extraGroups = [
    "acme"
    "${config.services.rspamd.group}"
  ];

  services.nginx = {
    enable = true;

    virtualHosts = {
      "${config.networking.fqdn}" = {
        listenAddresses = builtins.map (
          ip: (builtins.elemAt (lib.strings.splitString "/" ip) 0)
        ) config.networking.wireguard.interfaces.wg0.ips;
        default = true;
        forceSSL = true;
        enableACME = false;
        sslCertificate = "${config.security.acme.certs.mail.directory}/fullchain.pem";
        sslCertificateKey = "${config.security.acme.certs.mail.directory}/key.pem";

        locations = {
          "/" = {
            recommendedProxySettings = true;
            proxyPass = "http://unix:/run/rspamd/rspamd.sock";
          };
        };
      };
      "autoconfig.${config.networking.domain}" = {
        acmeRoot = null;
        addSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            extraConfig = ''
              add_header Content-Type text/xml;
              charset utf-8;
            '';
            root = "${autoconfig}/";
          };
        };
      };
    };
  };
}
