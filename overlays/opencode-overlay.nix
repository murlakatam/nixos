{
  opencodeSrc,
  ohMyOpencodeSrc,
  ...
}: final: prev: {
  opencode = prev.opencode.overrideAttrs (oldAttrs: let
    version = "latest";
    src = opencodeSrc;
  in {
    inherit version src;

    # We must also update the inner node_modules derivation to use the new source.
    # Nixpkgs defines this as a separate derivation, so we override it here.
    node_modules = oldAttrs.node_modules.overrideAttrs (oldNmAttrs: {
      inherit version src;

      # IMPORTANT: The dependencies (bun.lockb) change with the source.
      # You cannot know this hash ahead of time.
      # We set it to an empty string to force the build to fail and print the correct hash.
      outputHash = "sha256-Ws/XERjxQSK8HIDrE/8608TB5gBe4qoFE9mmssry78Y=";
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
    version = "latest";
    src = ohMyOpencodeSrc;

    # We need nodejs so patchShebangs can find 'node' for the tsc scripts
    nativeBuildInputs = [ prev.bun prev.nodejs ];

    # Create a separate derivation for dependencies (FOD)
    node_modules = prev.stdenvNoCC.mkDerivation {
      name = "${pname}-node_modules";
      inherit src;
      nativeBuildInputs = [ prev.bun ];
      
      buildPhase = ''
        export HOME=$(mktemp -d)
        bun install --frozen-lockfile --no-progress
      '';

      installPhase = ''
        mkdir -p $out
        cp -r node_modules $out/
      '';

      # Keep this true to preserve the hash
      dontFixup = true; 
      
      outputHash = "sha256-rC3UZgskHv4BPnm5IaQ6voDayHv1x7MFO1GL+wfxw/E=";
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
