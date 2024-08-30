{ env, config, ... }:
{
  users = {
    mutableUsers = false;
    users = {
      ${env.user} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        uid = 1000;
        hashedPasswordFile = config.sops.secrets."user/hashedPassword".path;
        openssh.authorizedKeys.keys = [ env.ssh_key ];
      };

      vmail = {
        group = "vmail";
        isSystemUser = true;
      };
      postfix = {
        group = "postfix";
        isSystemUser = true;
      };
    };
    groups = {
      vmail = { };
      postfix = { };
    };
  };

  sops.secrets = {
    "user/hashedPassword" = {
      neededForUsers = true;
    };
  };
}
