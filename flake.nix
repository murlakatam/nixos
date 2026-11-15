{
  description = "My flake NixOs configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-index-database = {
    #   url = "github:nix-community/nix-index-database";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secrets management. See ./docs/secretsmgmt.md
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=latest";
    };
    ohMyOpencodeSrc = {
      url = "github:code-yeongyu/oh-my-opencode";
      flake = false;
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    asus-dialpad-driver = {
      url = "github:asus-linux-drivers/asus-dialpad-driver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules = {
      url = "github:nix-community/nixos-facter-modules";
    };
    # Private: herdr skill stack incl. the vendored Sharesies ai-marketplace
    # herdr plugin. Root can't fetch it, so nixos-rebuild-ai / `make system`
    # run `nix flake archive` as the user first to put it in the store.
    herdr-nix.url = "git+ssh://git@github.com/murlakatam/herdr-nix";
    # Declarative Radarr/Sonarr/Prowlarr config (fork of upidapi/declarr; adds --diff, bug fixes).
    declarr = {
      url = "github:murlakatam/declarr/4fcf5803d2f74e1b9b1f17d7ed76bfd73cb45dae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-ld,
    # nix-index-database,
    nix-flatpak,
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
        pkgs.glibc
        pkgs.gmp
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

    # Shared NixOS modules (options under dotfiles.*), importable by any host/flake.
    nixosModules = {
      tailscale = ./modules/shared/nixos/tailscale.nix;
      default = {imports = [./modules/shared/nixos/tailscale.nix];};
    };

    nixosConfigurations = let
      # Build a NixOS system for the given host name from a module list.
      mkHost = hostName: modules:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit systems;
            inherit inputs;
            inherit username;
            host = hostName;
            inherit outputs;
          };
          modules = [self.nixosModules.default] ++ modules;
        };
    in {
      "${host}" = mkHost host [
        # Import global-env-vars.nix inside a module where pkgs is available
        ({pkgs, ...}: {
          _module.args.globalEnvVars = mkGlobalEnvVars pkgs;
        })
        nix-ld.nixosModules.nix-ld
        nix-flatpak.nixosModules.nix-flatpak
        ./hosts/${host}/config.nix
        home-manager.nixosModules.home-manager
        # nix-index-database.nixosModules.nix-index
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

      mediabox = mkHost "mediabox" [
        inputs.disko.nixosModules.disko
        inputs.nixos-facter-modules.nixosModules.facter
        inputs.sops-nix.nixosModules.sops
        {nixpkgs.config.allowUnfree = true;}
        ./hosts/mediabox/config.nix
      ];
    };
  };
}
