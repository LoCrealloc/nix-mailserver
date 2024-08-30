pkgs:
let
  mkScripts = builtins.mapAttrs (name: deps:
    pkgs.stdenvNoCC.mkDerivation {
      inherit name;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      unpackPhase = "true";
      installPhase = ''
        mkdir -p $out/bin
        cp ${./${name}.sh} $out/bin/${name}
        chmod +x $out/bin/${name}
      '';
      postFixup = ''
        wrapProgram $out/bin/${name} --set PATH ${pkgs.lib.makeBinPath deps}
      '';
    });
  scripts = mkScripts {
    add = with pkgs; [
      git
      mktemp
      coreutils
      nix # nix-instantiate
      openssh
      sops
      mkpasswd
      gnused # sed
      findutils
      nixos-install-tools # nixos-generate-config
      ssh-to-age
    ];
    update = with pkgs; [
      coreutils
      nix
      nixos-rebuild
      git
      openssh
    ];
  };
in
scripts
