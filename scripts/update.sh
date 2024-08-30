#!/usr/bin/env bash

update=false
build_on_host=false
cleanup=false

while getopts "ubch:" flag
do
    case $flag in
		b) build_on_host=true;;
        u) update=true;;
        h) ssh_connection=${OPTARG};;
		c) cleanup=true;;
    esac
done

update_host() {
	rebuild_args="--target-host $ssh_connection"

	echo "Updating $@"

	if [ "$build_on_host" = true ] ; then
		rebuild_args+=" --build-host $ssh_connection"
	fi

	NIX_SSHOPTS="-A" nixos-rebuild switch $rebuild_args --use-remote-sudo --flake ".#mail"
}

cleanup_host() {
	echo "Cleaning up $@"

	ssh -A $ssh_connection "sudo nix-collect-garbage -d"
}

if  [[ ! -v ssh_connection ]] ; then
	echo "You must specify a connection"
	exit
fi

if [ "$update" = true ] ; then
	echo "Updating flake inputs"

	nix flake update
fi

if [ "$cleanup" = true ] ; then
	cleanup_host $host
fi

update_host $host

echo "Done!"
