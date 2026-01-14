#!/usr/bin/env zsh
set -e

# Configuration
OVERLAY_FILE="overlays/opencode-overlay.nix"
FLAKE_DIR="$(pwd)" # Assume running from root

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
  
  # FIX: We now import 'pkgs' from the Flake itself to ensure 'bun' versions match exactly.
  # We use builtins.getFlake on the current directory.
  output=$(nix-build --no-out-link -E "
    let
      flake = builtins.getFlake (toString $FLAKE_DIR);
      pkgs = flake.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = \"$name-deps\";
      src = $src; 
      nativeBuildInputs = [ pkgs.bun ];
      
      unpackPhase = ''
        mkdir source
        cp -r \$src/. source
        cd source
        chmod -R u+w .
      '';

      buildPhase = ''
        export HOME=\$(mktemp -d)
        # Match the overlay exactly:
        ${pkgs.bun}/bin/bun install --frozen-lockfile --no-progress --ignore-scripts
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
  hash=$(echo "$output" | grep "got:" | awk '{print $2}')

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
    log "🛠 Patching $OVERLAY_FILE for OpenCode -> $OPENCODE_HASH"
    sed -i -E "s|(outputHash = \")[^\"]*(\"; # opencode-hash)|\1$OPENCODE_HASH\2|" "$OVERLAY_FILE"
else
    log_error "❌ Invalid OpenCode hash captured: $OPENCODE_HASH"
    exit 1
fi

# --- 2. Update Oh-My-OpenCode ---
OMO_HASH=$(prefetch_bun_deps "$OH_MY_OPENCODE_PATH" "oh-my-opencode")
if [[ "$OMO_HASH" == sha256-* ]]; then
    log "🛠 Patching $OVERLAY_FILE for Oh-My-OpenCode -> $OMO_HASH"
    sed -i -E "s|(outputHash = \")[^\"]*(\"; # oh-my-opencode-hash)|\1$OMO_HASH\2|" "$OVERLAY_FILE"
else
    log_error "❌ Invalid Oh-My-OpenCode hash captured: $OMO_HASH"
    exit 1
fi

log_success "🎉 Overlay updated successfully!"