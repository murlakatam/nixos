#!/usr/bin/env zsh
set -e

# Configuration
OVERLAY_FILE="overlays/opencode-overlay.nix"

print -P "%F{cyan}🔄 Getting source paths from Flake inputs...%f"
OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.opencodeSrc.outPath')
OH_MY_OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.ohMyOpencodeSrc.outPath')

print -P "%F{green}✅ OpenCode Source:%f $OPENCODE_PATH"
print -P "%F{green}✅ Oh-My-OpenCode Source:%f $OH_MY_OPENCODE_PATH"

prefetch_bun_deps() {
  local src=$1
  local name=$2
  
  print -P "%F{yellow}⏳ Prefetching dependencies for $name...%f"
  
  local output
  # Force a build failure to get the "got: sha256-..." hash
  output=$(nix-build --no-out-link -E "
    with import <nixpkgs> {};
    stdenvNoCC.mkDerivation {
      name = \"$name-deps\";
      src = builtins.toPath \"$src\";
      nativeBuildInputs = [ bun ];
      buildPhase = ''
        export HOME=\$(mktemp -d)
        bun install --frozen-lockfile --no-progress
      '';
      installPhase = ''
        mkdir -p \$out
        cp -r node_modules \$out/
      '';
      dontFixup = true;
      outputHashMode = \"recursive\";
      outputHashAlgo = \"sha256\";
      outputHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";
    }
  " 2>&1)

  # Extract hash from 'got: sha256-...' line
  local hash
  hash=$(echo "$output" | grep "got:" | cut -d' ' -f4 | tr -d ' ')

  if [[ -z "$hash" ]]; then
    print -P "%F{red}❌ Failed to calculate hash for $name%f"
    echo "$output"
    exit 1
  fi
  
  print -P "%F{blue}🔑 New Hash for $name:%f $hash"
  echo "$hash"
}

# 1. Update OpenCode
OPENCODE_HASH=$(prefetch_bun_deps "$OPENCODE_PATH" "opencode")

# We use -E for extended regex.
# Group 1 matches: outputHash = "
# We replace the middle (the old hash)
# Group 2 matches: "; # opencode-hash
# The replacement \1$HASH\2 keeps the groups (indentation + comment) intact.
sed -i -E "s|(outputHash = \")[^\"]*(\"; # opencode-hash)|\1$OPENCODE_HASH\2|" "$OVERLAY_FILE"

# 2. Update Oh-My-OpenCode
OMO_HASH=$(prefetch_bun_deps "$OH_MY_OPENCODE_PATH" "oh-my-opencode")
sed -i -E "s|(outputHash = \")[^\"]*(\"; # oh-my-opencode-hash)|\1$OMO_HASH\2|" "$OVERLAY_FILE"

print -P "%F{green}🎉 Overlay updated successfully!%f"