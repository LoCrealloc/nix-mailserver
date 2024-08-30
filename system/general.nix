{ pkgs, lib, ... }:
{
  time.timeZone = "Europe/Berlin";

  i18n.defaultLocale = "de_DE.UTF-8";
  console = {
    keyMap = lib.mkForce "de";
    useXkbConfig = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    btop
    tcpdump
    rsync
    dig
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };

  security.sudo.enable = true;
  security.pam.sshAgentAuth = {
    enable = true;
  };

  security.pam.services.sudo.sshAgentAuth = true;

  programs.vim.defaultEditor = true;

  system.stateVersion = "24.05";
}
