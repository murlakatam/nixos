#!/usr/bin/env zsh
set -e

# Configuration
OVERLAY_FILE="overlays/opencode-overlay.nix"

log() { print -P "%F{cyan}$1%f" >&2; }
log_success() { print -P "%F{green}$1%f" >&2; }
log_error() { print -P "%F{red}$1%f" >&2; }

if [[ ! -f "$OVERLAY_FILE" ]]; then
  log_error "❌ Could not find overlay file at: $OVERLAY_FILE"
  exit 1
fi

log "🔄 Getting source paths from Flake inputs..."
OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.opencodeSrc.outPath')
OH_MY_OPENCODE_PATH=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.ohMyOpencodeSrc.outPath')

log_success "✅ OpenCode Source: $OPENCODE_PATH"
log_success "✅ Oh-My-OpenCode Source: $OH_MY_OPENCODE_PATH"

prefetch_bun_deps() {
  local src=$1
  local name=$2
  
  print -P "%F{yellow}⏳ Prefetching dependencies for $name...%f" >&2
  
  local output
  local code=0
  
  # FIX: src = $src (UNQUOTED). This makes it a Path Literal in Nix.
  # This tells Nix to strictly mount this path into the sandbox.
  output=$(nix-build --no-out-link -E "
    with import <nixpkgs> {};
    stdenvNoCC.mkDerivation {
      name = \"$name-deps\";
      src = $src; 
      nativeBuildInputs = [ bun ];
      
      # FIX: Robust unpack that handles the read-only store path
      unpackPhase = ''
        mkdir source
        cp -r \$src/. source
        cd source
        chmod -R u+w .
      '';

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
  " 2>&1) || code=$?

  local hash
  hash=$(echo "$output" | grep "got:" | cut -d' ' -f4 | tr -d ' ')

  if [[ -z "$hash" ]]; then
    log_error "❌ Failed to calculate hash for $name (Exit Code: $code)"
    log_error "👇 FULL BUILD LOGS 👇"
    echo "$output" >&2
    exit 1
  fi
  
  print -P "%F{blue}🔑 New Hash for $name:%f $hash" >&2
  echo "$hash"
}

# --- 1. Update OpenCode ---
OPENCODE_HASH=$(prefetch_bun_deps "$OPENCODE_PATH" "opencode")
if [[ "$OPENCODE_HASH" == sha256-* ]]; then
    log "🛠 Patching $OVERLAY_FILE with new OpenCode hash..."
    sed -i -E "s|(outputHash = \")[^\"]*(\"; # opencode-hash)|\1$OPENCODE_HASH\2|" "$OVERLAY_FILE"
else
    log_error "❌ Invalid OpenCode hash captured: $OPENCODE_HASH"
    exit 1
fi

# --- 2. Update Oh-My-OpenCode ---
OMO_HASH=$(prefetch_bun_deps "$OH_MY_OPENCODE_PATH" "oh-my-opencode")
if [[ "$OMO_HASH" == sha256-* ]]; then
    log "🛠 Patching $OVERLAY_FILE with new Oh-My-OpenCode hash..."
    sed -i -E "s|(outputHash = \")[^\"]*(\"; # oh-my-opencode-hash)|\1$OMO_HASH\2|" "$OVERLAY_FILE"
else
    log_error "❌ Invalid Oh-My-OpenCode hash captured: $OMO_HASH"
    exit 1
fi

log_success "🎉 Overlay updated successfully!"