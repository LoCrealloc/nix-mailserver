{ config, env, ... }:
{
  networking.wireguard.interfaces.wg0 = {
    ips = [ env.wg.ip ];

    listenPort = 51820;

    privateKeyFile = config.sops.secrets."wg0-priv".path;

    peers = [
      {
        publicKey = env.wg.server-key;

        allowedIPs = env.wg.allowedIPs;
        endpoint = env.wg.endpoint;

        presharedKeyFile = config.sops.secrets."wg0-psk".path;

        persistentKeepalive = 25;
        dynamicEndpointRefreshSeconds = 60;
      }
    ];
  };

  sops.secrets = {
    "wg0-priv" = {
      format = "binary";
      sopsFile = ../secrets/wg0.key;
    };
    "wg0-psk" = {
      format = "binary";
      sopsFile = ../secrets/wg0.psk;
    };
  };
}
