{inputs, ...}: final: prev: {
  oh-my-opencode = prev.stdenvNoCC.mkDerivation rec {
    pname = "oh-my-opencode";
    version = (builtins.fromJSON (builtins.readFile "${inputs.ohMyOpencodeSrc}/package.json")).version;
    src = inputs.ohMyOpencodeSrc;

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
