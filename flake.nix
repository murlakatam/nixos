{
  description = "My flake NixOs configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    yazi.url = "github:sxyazi/yazi";
  };
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-ld,
    nix-index-database,
    nix-flatpak,
    yazi,
    ...
  } @ inputs: let
    inherit (self) outputs;

    systems = [
      "x86_64-linux"
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
    packages = forAllSystems (system: {});

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
          nix-flatpak.nixosModules.nix-flatpak
          ./hosts/${host}/config.nix
          home-manager.nixosModules.home-manager
          nix-index-database.nixosModules.nix-index
          {
            # Apply overlays to nixpkgs
            nixpkgs.overlays = builtins.attrValues outputs.overlays;

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
              imports = [
                nix-flatpak.homeManagerModules.nix-flatpak
                ./hosts/${host}/home.nix
              ];
            };
            nixpkgs.config.allowUnfree = true;
            programs.nix-ld.dev.enable = true;
          }
        ];
      };
    };
  };
}
