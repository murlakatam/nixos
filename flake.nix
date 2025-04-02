{
  description = "My flake NixOs configuration";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&ref=nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # stylix.url = "github:danth/stylix";
    # neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    # nixvim.url = "github:nix-community/nixvim";
    # nix-inspect.url = "github:bluskript/nix-inspect";
    # rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    # zen-browser.url = "github:0xc000022070/zen-browser-flake";
    # flake-utils.url = "github:numtide/flake-utils";
    # helix = {
    #   url = "github:helix-editor/helix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    # yazi.url = "github:sxyazi/yazi";

    # hyprland = {
    #  url = "github:hyprwm/hyprland";
    #  inputs.nixpkgs.follows = "nixpkgs";
    # };

    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-ld,
    nix-index-database,
    ...
  } @ inputs: let
    inherit (self) outputs;

    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    host = "proartp16";
    username = "eugene";
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Import overlays explicitly
    overlays = import ./overlays {inherit inputs;};

    # Function to create globalEnvVars with the correct pkgs for NIX_LD
    mkGlobalEnvVars = pkgs: {
      NIX_LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc
        pkgs.libunwind
        pkgs.libuuid
        pkgs.icu
        pkgs.openssl
        pkgs.zlib
        pkgs.curl
      ]}";
      NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";
    };
  in {
    packages =
      forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

    formatter =
      forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    overlays = overlays; # Export the overlays attribute set

    nixosConfigurations = {
      "${host}" = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit systems;
          inherit inputs;
          inherit username;
          inherit host;
          inherit outputs;
        };
        modules = [
          # Import global-env-vars.nix inside a module where pkgs is available
          ({pkgs, ...}: {
            _module.args.globalEnvVars = mkGlobalEnvVars pkgs;
          })
          nix-ld.nixosModules.nix-ld
          ./hosts/${host}/config.nix
          home-manager.nixosModules.home-manager
          nix-index-database.nixosModules.nix-index
          {
            home-manager.extraSpecialArgs = {
              inherit username;
              inherit inputs;
              inherit host;
              inherit systems;
              inherit outputs; # Ensure outputs is passed for overlays
            };
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.${username} = {pkgs, ...}: {
              # Define globalEnvVars inside the Home Manager configuration
              _module.args.globalEnvVars = mkGlobalEnvVars pkgs;
              imports = [./hosts/${host}/home.nix];
            };
            nixpkgs.config.allowUnfree = true;
            programs.nix-ld.dev.enable = true;
          }
        ];
      };
    };
  };
}
