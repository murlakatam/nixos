# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
  };

  azure-creds = import ./azure-creds-overlay.nix;
  # Helix nightly overlay
  # helix-nightly = final: prev: {
  #   helix-nightly = prev.helix.overrideAttrs (oldAttrs: {
  #     src = inputs.helix-nightly;
  #     version = "nightly-${inputs.helix-nightly.rev}";
  #     cargoHash = "";
  #     cargoDeps = prev.rustPlatform.importCargoLock {
  #     lockFile = "${inputs.helix-nightly}/Cargo.lock";
  #     };
  #   });
  # };
  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
