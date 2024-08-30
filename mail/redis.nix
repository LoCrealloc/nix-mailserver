{ config, ... }: {
  services.redis = {
    servers.rspamd = {
      enable = true;
      port = 0;
      user = config.services.rspamd.user;
    };
  };
}
