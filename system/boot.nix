{ env, config, ... }:
{
  boot = {
    loader = {
      grub = {
        enable = true;
      };
    };

    #kernelParams = [ "ip=dhcp" ];

    initrd = {
      systemd.network = config.systemd.network;
      network = {
        enable = true;
        flushBeforeStage2 = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = map (key: "command=\"systemctl default\" ${key}") env.ssh_keys;
          hostKeys = [ "/etc/secrets/initrd/host_ssh_key" ];
        };
      };
    };
  };
}
