{ env, ... }:
{

  networking = {
    hostName = env.hostname;
    domain = env.domain;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        993
        25
        465
      ]; # IMAP/S SMTP SMTP/S
    };

    useDHCP = false;
  };

  systemd.network = {
    enable = true;

    networks."wan" = {
      networkConfig.DHCP = "no";

      matchConfig.Name = "enp1s0";

      address = [
        "${env.ip.v4}/32"
        "${env.ip.v6}/64"
      ];

      # hetzner specific stuff
      routes = [
        { routeConfig.Gateway = "fe80::1"; }
        {
          routeConfig = {
            Destination = "172.31.1.1";
          };
        }
        {
          routeConfig = {
            Gateway = "172.31.1.1";
            GatewayOnLink = true;
          };
        }
      ];
    };
  };
}
