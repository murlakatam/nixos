{
  opencodeSrc,
  ohMyOpencodeSrc,
  ...
}: final: prev: {
  opencode = prev.opencode.overrideAttrs (oldAttrs: let
    packageMetadata = builtins.fromJSON (builtins.readFile "${opencodeSrc}/packages/opencode/package.json");
    version = packageMetadata.version;
    src = opencodeSrc;
  in {
    inherit version src;

    # We must also update the inner node_modules derivation to use the new source.
    # Nixpkgs defines this as a separate derivation, so we override it here.
    node_modules = oldAttrs.node_modules.overrideAttrs (oldNmAttrs: {
      inherit version src;

      buildPhase = ''
        export HOME=$(mktemp -d)
        bun install --frozen-lockfile --no-progress --ignore-scripts
      '';

      # We set the marker comment that is replaced by update-overlay-hashes.zsh script (see scripts folder)
      outputHash = "sha256-FQCOlh17tzREVMRoG4KOI5V4a+3tvQlZE5//ClNFxqM="; # opencode-hash
    });

    # The patch file referencing 'relax-bun-version-check' is inside nixpkgs,
    # but might not apply cleanly to 'latest', or you might not have access to it easily.
    # We remove the patch file and apply the fix manually using sed.
    patches = [];

    postPatch = ''
      # Apply the "Relax Bun version check" logic manually
      # This replaces the error throw with a console warning
      substituteInPlace packages/script/src/index.ts \
        --replace 'throw new Error(`This script requires bun' \
                  'console.warn(`Warning: This script expects bun'
    '';

    # Update environment variables for the runtime
    env =
      oldAttrs.env
      // {
        OPENCODE_VERSION = version;
        OPENCODE_CHANNEL = "nightly";
        OPENCODE_EXPERIMENTAL_PLAN_MODE = 1;
      };
  });

  oh-my-opencode = prev.stdenvNoCC.mkDerivation rec {
    pname = "oh-my-opencode";
    version = (builtins.fromJSON (builtins.readFile "${ohMyOpencodeSrc}/package.json")).version;
    src = ohMyOpencodeSrc;

    # We need nodejs so patchShebangs can find 'node' for the tsc scripts
    nativeBuildInputs = [prev.bun prev.nodejs];

    # Create a separate derivation for dependencies (FOD)
    node_modules = prev.stdenvNoCC.mkDerivation {
      name = "${pname}-node_modules";
      inherit src;
      nativeBuildInputs = [prev.bun];

      buildPhase = ''
        export HOME=$(mktemp -d)
        bun install --frozen-lockfile --no-progress --ignore-scripts
      '';

      installPhase = ''
        mkdir -p $out
        cp -r node_modules $out/
      '';

      # Keep this true to preserve the hash
      dontFixup = true;
      # We set the marker comment that is replaced by update-overlay-hashes.zsh script (see scripts folder)
      outputHash = "sha256-viYkTVKkI+guqKALKHNuPrOzhAhaLv/X+EW45xByzns="; # oh-my-opencode-hash
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    };

    buildPhase = ''
      # 1. Copy node_modules (instead of symlinking) so we can modify them
      cp -r ${node_modules}/node_modules .

      # 2. Make them writable
      chmod -R u+w node_modules

      # 3. Patch the shebangs (fixes /usr/bin/env node -> /nix/store/.../bin/node)
      patchShebangs node_modules

      # 4. Run the build
      export HOME=$(mktemp -d)
      bun run build
    '';

    installPhase = ''
      mkdir -p $out/share/oh-my-opencode
      cp -r dist $out/share/oh-my-opencode/
    '';
  };
}
