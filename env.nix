{
  system = "x86_64-linux";

  user = "loc";
  admin_email = "loc@locrealloc.de";

  ssh_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAvFUhkhp13FXwFfbBrAEMHWjBbo6pNhKPwp12DAoWS+ loc@locs-thinkbook"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINeSROnV/rwwD0TuUQsksyfTvB2/u843GtHKbhhY+7vE loc@locs-desktop"
  ];

  hostname = "mail";
  domain = "locrealloc.de";

  ip = {
    v4 = "159.69.179.51";
    v6 = "2a01:4f8:c012:681c::1";
  };

  wg = {
    server-key = "kzT+y5SitcmBOK2xfPtui9UJGYdAEEOulFSa6k7WVgU=";
    ip = "10.10.1.1/32";
    endpoint = "home.locnet.dev:51822";
    allowedIPs = [
      "10.0.0.0/8"
      "192.168.0.0/16"
    ]; # protected by firewall
  };
}
