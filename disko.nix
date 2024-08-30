{
  disk ? "/dev/sda",
  ...
}:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            flag = {
              size = "1M";
              type = "EF02";
            };
            boot = {
              start = "2M";
              end = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings.allowDiscards = true;
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "@" = {
                      mountOptions = [ "compress=zstd" ];
                      mountpoint = "/";
                    };
                    "@var_vmail" = {
                      mountOptions = [ "compress=zstd" ];
                      mountpoint = "/var/vmail";
                    };
                    "@nix" = {
                      mountOptions = [ "compress=zstd" ];
                      mountpoint = "/nix";
                    };
                    "@snapshots" = {
                      mountOptions = [ "compress=zstd" ];
                      mountpoint = "/.snaphots";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
