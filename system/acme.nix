{ config, env, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "${env.admin_email}";
      dnsProvider = "hetzner";
      dnsResolver = "hydrogen.ns.hetzner.com";
      environmentFile = config.sops.secrets."acme_hetzner".path;
      group = "acme";
    };

    certs.mail = {
      domain = config.networking.fqdn;
      extraDomainNames = [
        "imap.${config.networking.domain}"
        "smtp.${config.networking.domain}"
      ];
      reloadServices = [
        "dovecot2"
        "postfix"
        "nginx"
      ];
    };
  };

  sops.secrets = {
    "acme_hetzner" = {
      sopsFile = ../secrets/acme_hetzner;
      format = "binary";
      group = "acme";
      mode = "0440";
    };
  };

}
