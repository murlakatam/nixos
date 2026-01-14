#!/usr/bin/env zsh
set -e

# Configuration
OVERLAY_FILE="overlays/opencode-overlay.nix"

# Debug helper: prints to stderr so it shows up even inside $() captures
log() {
  print -P "%F{cyan}$1%f" >&2
}

log_success() {
  print -P "%F{green}$1%f" >&2
}

log_error() {
  print -P "%F{red}$1%f" >&2
}

# 1. Sanity Check: Ensure we are in the right directory
if [[ ! -f "$OVERLAY_FILE" ]]; then
  log_error "❌ Could not find overlay file at: $OVERLAY_FILE"
  log_error "   Current Directory: $(pwd)"
  log_error "   Please run this script from the root of your dotfiles repository."
  exit 1
fi

log "🔄 Getting source paths from Flake inputs..."

# Nix evaluation can sometimes be noisy or fail, capture it carefully
OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.opencodeSrc.outPath')
OH_MY_OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.ohMyOpencodeSrc.outPath')

log_success "✅ OpenCode Source: $OPENCODE_PATH"
log_success "✅ Oh-My-OpenCode Source: $OH_MY_OPENCODE_PATH"

prefetch_bun_deps() {
  local src=$1
  local name=$2
  
  # Log to stderr so it doesn't pollute the return value
  print -P "%F{yellow}⏳ Prefetching dependencies for $name...%f" >&2
  
  local output
  # Run nix-build. capture stderr/stdout combined to parse the hash
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

  # Debugging: If something goes wrong, we might want to see the last few lines of output
  # echo "$output" | tail -n 5 >&2 

  # Extract hash from 'got: sha256-...' line
  local hash
  hash=$(echo "$output" | grep "got:" | cut -d' ' -f4 | tr -d ' ')

  if [[ -z "$hash" ]]; then
    log_error "❌ Failed to calculate hash for $name"
    log_error "   Nix Build Output:"
    echo "$output" >&2
    exit 1
  fi
  
  print -P "%F{blue}🔑 New Hash for $name:%f $hash" >&2
  
  # ONLY print the hash to stdout so the variable captures it
  echo "$hash"
}

# --- 1. Update OpenCode ---
OPENCODE_HASH=$(prefetch_bun_deps "$OPENCODE_PATH" "opencode")

# Verify we captured a clean hash (sanity check)
if [[ "$OPENCODE_HASH" != sha256-* ]]; then
    log_error "❌ captured invalid hash for OpenCode: $OPENCODE_HASH"
    exit 1
fi

log "🛠 Patching $OVERLAY_FILE with new OpenCode hash..."
sed -i -E "s|(outputHash = \")[^\"]*(\"; # opencode-hash)|\1$OPENCODE_HASH\2|" "$OVERLAY_FILE"


# --- 2. Update Oh-My-OpenCode ---
OMO_HASH=$(prefetch_bun_deps "$OH_MY_OPENCODE_PATH" "oh-my-opencode")

if [[ "$OMO_HASH" != sha256-* ]]; then
    log_error "❌ captured invalid hash for Oh-My-OpenCode: $OMO_HASH"
    exit 1
fi

log "🛠 Patching $OVERLAY_FILE with new Oh-My-OpenCode hash..."
sed -i -E "s|(outputHash = \")[^\"]*(\"; # oh-my-opencode-hash)|\1$OMO_HASH\2|" "$OVERLAY_FILE"

log_success "🎉 Overlay updated successfully!"