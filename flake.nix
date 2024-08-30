{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      disko,
      ...
    }@inputs:
    let

      env = import ./env.nix;
      lib = nixpkgs.lib;

      system = env.system;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (self: super: { dovecot = super.dovecot.override { withPgSQL = true; }; })
          (self: super: { postfix = super.postfix.override { withPgSQL = true; }; })
        ];
      };

      specialArgs = inputs // {
        inherit env;
        disk = "/dev/sda";
      };
    in
    {
      nixosConfigurations."${env.hostname}" = lib.nixosSystem {
        inherit system pkgs specialArgs;
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko

          ./hardware-configuration.nix
          ./disko.nix
          ./system
          ./mail

        ];

      };

      packages =
        let
          defaultSystems = [ "x86_64-linux" ];

          eachDefaultSystem = lib.genAttrs defaultSystems;
        in
        eachDefaultSystem (system: import ./scripts (import nixpkgs { inherit system; }));
    };
}
