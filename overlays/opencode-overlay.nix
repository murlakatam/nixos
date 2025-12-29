{opencodeSrc, ...}: final: prev: {
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
      outputHash = "sha256-4RckAej/MeG7I7qbFkx5wwsvESueOCGOHkHrIK6//3M=";
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
      };
  });
}
