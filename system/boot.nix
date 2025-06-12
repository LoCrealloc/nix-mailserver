{ env, ... }:
{
  boot = {
    loader = {
      grub = {
        enable = true;
      };
    };

    kernelParams = [ "ip=dhcp" ];

    initrd = {
      systemd.users.root.shell = "/bin/cryptsetup-askpass";
      network = {
        enable = true;
        # maybe switch to static configuration?
        udhcpc.enable = true;
        flushBeforeStage2 = true;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = env.ssh_keys;
          hostKeys = [ "/etc/secrets/initrd/host_ssh_key" ];
        };
        postCommands = ''
          echo 'cryptsetup-askpass || echo "Unlock was successful; exiting SSH session" && exit 1' >> /root/.profile
        '';
      };
    };
  };
}
