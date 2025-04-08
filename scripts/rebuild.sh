#!/usr/bin/env bash
#
# I believe there are a few ways to do this:
#
#    1. My current way, using a minimal /etc/nixos/configuration.nix that just imports my config from my home directory (see it in the gist)
#    2. Symlinking to your own configuration.nix in your home directory (I think I tried and abandoned this and links made relative paths weird)
#    3. My new favourite way: as @clot27 says, you can provide nixos-rebuild with a path to the config, allowing it to be entirely inside your dotfies, with zero bootstrapping of files required.
#       `nixos-rebuild switch -I nixos-config=path/to/configuration.nix`
#    4. If you uses a flake as your primary config, you can specify a path to `configuration.nix` in it and then `nixos-rebuild switch —flake` path/to/directory
# As I hope was clear from the video, I am new to nixos, and there may be other, better, options, in which case I'd love to know them! (I'll update the gist if so)

# A rebuild script that commits on a successful build           
set -e

# Initialize default flags
update_flake=false
repair=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-flake)
      update_flake=true
      shift
      ;;
    --repair)
      repair=true
      shift
      ;;
    *)
      # Unknown option
      echo "Unknown option: $1"
      shift
      ;;
  esac
done

# Edit your config
#$EDITOR configuration.nix 

# cd to your config dir
pushd ~/dotfiles/nixos/

code --wait .

# Early return if no changes were detected (thanks @singiamtel!)
if git diff --quiet '*.nix' '*.lock' '*.zsh' '*.json'; then
    echo "No changes detected, exiting."
    popd
    exit 0
fi

# Autoformat your nix files
alejandra . &>/dev/null \
  || ( alejandra . ; echo "formatting failed!" && exit 1)

# Shows your changes
git diff -U0 '*.nix'

echo "NixOS Rebuilding..."

# Only run flake update if the flag is set
if $update_flake; then
    echo "Updating flake..."
    sudo nix flake update
fi


if [ "$repair" = true ]; then
  echo "Repairing botched upgrade..."
  sudo nixos-rebuild switch --flake /home/eugene/dotfiles/nixos#proartp16 --show-trace --repair
else
  # Default rebuild, output simplified errors, log trackebacks
  #sudo nixos-rebuild switch -I nixos-config=/home/eugene/dotfiles/nixos/configuration.nix #&>nixos-switch.log || (cat nixos-switch.log | grep --color error && exit 1)
  sudo nixos-rebuild switch --flake /home/eugene/dotfiles/nixos#proartp16 --show-trace #&>nixos-switch.log || (cat nixos-switch.log | grep --color error && exit 1)
fi

#homemanager change
#if ! git diff --quiet -- 'home.nix'; then
#echo "Homemanager change detected..."
#journalctl -xe --unit home-manager-eugene.service
#fi

# Get current generation metadata
current=$(nixos-rebuild list-generations | grep current)

# Commit all changes witih the generation metadata
git commit -am "$current"

git pushup

# Back to where you were
popd

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
