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
recreate_lock_file=false # <-- Added new flag

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-flake)
      update_flake=true
      shift
      ;;
    --recreate-lock-file) # <-- Added new option
      recreate_lock_file=true
      update_flake=true # A recreate is a type of update, so we set both
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

# cd to your config dir
pushd ~/dotfiles/nixos/

code --wait .

# Early return if no changes were detected (and no update is requested)
if [[ "$update_flake" != "true" ]] && git diff --quiet '*.nix' '*.lock' '*.zsh' '*.json' '*.sh' '*.Makefile'; then
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

# --- MODIFIED UPDATE LOGIC ---
# Handle flake updates, prioritizing recreate-lock-file
if $recreate_lock_file; then
    echo "Forcing flake update by recreating lock file..."
    sudo nix flake update --recreate-lock-file
elif $update_flake; then
    echo "Updating flake..."
    sudo nix flake update
fi
# --- END OF MODIFICATION ---


if [ "$repair" = true ]; then
  echo "Repairing botched upgrade..."
  sudo nixos-rebuild switch --flake /home/eugene/dotfiles/nixos#proartp16 --show-trace --repair
else
  # Default rebuild, output simplified errors, log trackebacks
  sudo nixos-rebuild switch --flake /home/eugene/dotfiles/nixos#proartp16 --show-trace
fi
# Check for Home Manager changes and show logs if detected
if ! git diff --quiet -- 'hosts/proartp16/home.nix' 'modules/homeManagerModules/'; then
  echo "Home Manager change detected, showing service logs..."
  journalctl -xe --unit home-manager-eugene.service || true
fi
# Get current generation metadata
current=$(nixos-rebuild list-generations | awk '$NF == "True" && NR>1 { $NF=""; print $0 }')

# Commit all changes with the generation metadata
git commit -am "$current"

git pushup

# Back to where you were
popd

# Notify all OK!
notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available