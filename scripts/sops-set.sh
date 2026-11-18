#!/usr/bin/env zsh
# Set one or more sops values in secrets/<host>.yaml without them ever being shown or put on a
# command line. Run it yourself in your own terminal, never through an agent.
#
#   zsh scripts/sops-set.sh [-f secrets/mediabox.yaml] <key> [<key>...]
#   zsh scripts/sops-set.sh --random <key>        # 32-hex random value, never shown
#
# Typed values: hidden, asked twice, must match and be non-empty, else nothing is changed.
# Prints only the stored length of each key.
set -euo pipefail
cd ~/dotfiles/nixos
export SOPS_AGE_KEY_CMD="nix run nixpkgs#ssh-to-age -- -private-key -i $HOME/.ssh/id_ed25519"
sops() { nix run nixpkgs#sops -- "$@"; }
jq() { nix run nixpkgs#jq -- "$@"; }

F=secrets/mediabox.yaml random=0
while [[ $# -gt 0 ]]; do
  case $1 in
    -f) F=$2; shift 2 ;;
    --random) random=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*) print -u2 "unknown option $1"; exit 1 ;;
    *) break ;;
  esac
done
[[ $# -gt 0 ]] || { print -u2 "usage: sops-set.sh [-f file] [--random] <key>..."; exit 1; }
[[ -f $F ]] || { print -u2 "$F not found"; exit 1; }

typeset -A vals
for k in "$@"; do
  if (( random )); then continue; fi
  read -rs "a?NEW value for $k (hidden): "; print >&2
  read -rs "b?again: "; print >&2
  [[ -n $a ]] || { print -u2 "$k: empty; nothing changed"; exit 1; }
  [[ $a == "$b" ]] || { print -u2 "$k: entries differ; nothing changed"; exit 1; }
  vals[$k]=$a
done
unset a b

for k in "$@"; do
  if (( random )); then
    nix run nixpkgs#openssl -- rand -hex 16 | tr -d '\n' | jq -Rs . | sops set --value-stdin "$F" "[\"$k\"]"
  else
    print -rn -- "${vals[$k]}" | jq -Rs . | sops set --value-stdin "$F" "[\"$k\"]"
  fi
done
unset vals

print "stored in $F (key: length):"
for k in "$@"; do
  print "  $k: $(sops -d --extract "[\"$k\"]" "$F" | wc -c | tr -d ' ')"
done
print "Next: tell the agent; it deploys (sops restartUnits apply the new value)."
