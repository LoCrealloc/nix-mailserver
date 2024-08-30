#!/usr/bin/env bash

ssh_connection=$1

known_hosts=$(mktemp)

pw=$(mkpasswd)

ssh_() {
	ssh -T -o "StrictHostKeyChecking no" -o UserKnownHostsFile="$known_hosts" "$ssh_connection" "$@"
}

nix_copy() {
	NIX_SSHOPTS="-o UserKnownHostsFile=$known_hosts -o StrictHostKeyChecking=no" nix copy \
		"$@"
}


system=${2:-$(echo "x86_64-linux")} #TODO

echo "system: $system"

# permanently enable flakes on live system
ssh_ <<SSH
mkdir -p ~/.config/nix/
echo experimental-features = nix-command flakes > ~/.config/nix/nix.conf
SSH

# disk partitioning
disko_script=$(nix run github:nix-community/disko -- --dry-run --mode disko ./disko.nix)

nix_copy --to "ssh://$ssh_connection" "$disko_script"
ssh_ $disko_script

echo "Finished disk partitioning"

# generate hardware configuration
ssh_ "nixos-generate-config --root /mnt --no-filesystems --show-hardware-config" > "./hardware-configuration.nix"

echo "Generated hardware configuration"

# create directories and generate age keys
ssh_ <<SSH
mkdir -p /mnt/etc/ssh
mkdir -p /mnt/etc/secrets/initrd

ssh-keygen -t ed25519 -P "" -f /mnt/etc/ssh/ssh_host_ed25519_key
ssh-keygen -t ed25519 -P "" -f /mnt/etc/secrets/initrd/host_ssh_key

nix profile install nixpkgs#ssh-to-age
SSH

echo "Generated ssh keys"

age_pubkey=$(ssh_ "ssh-to-age -i /mnt/etc/ssh/ssh_host_ed25519_key.pub")

echo "Generated age keys"

sed -i "/^creation_rules:/i\  - &server $age_pubkey" .sops.yaml
sed -i "\$a\          - *server" .sops.yaml

echo -e "user:\n  hashedPassword: $pw" > secrets/default.yml

sops -e -i secrets/default.yml
find secrets -type f -exec sops updatekeys -y {} \;

git add --intent-to-add "."

nixos_system=$(nix build --print-out-paths -L --no-link ".#nixosConfigurations.mail.config.system.build.toplevel")

echo "System build finished"

nix_copy --to "ssh://$ssh_connection?remote-store=local?root=/mnt" $nixos_system

echo "Copied system build to host"

ssh_ "nixos-install --no-root-passwd --no-channel-copy --system $nixos_system"

echo "System installed"
