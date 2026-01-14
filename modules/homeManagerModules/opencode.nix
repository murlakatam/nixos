{
  pkgs,
  config,
  ...
}: {
  # check the overlays for the packages build/installation
  home.packages = [
    pkgs.opencode # The editor
    pkgs.oh-my-opencode # The OmO plugin
    pkgs.nixd # The Language Server
    pkgs.alejandra # The Formatter
    pkgs.omnisharp-roslyn
    pkgs.pkgs.dotnetCorePackages.sdk_8_0
  ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    plugin = [
      "file://${pkgs.oh-my-opencode}/share/oh-my-opencode/dist/index.js"
      "opencode-antigravity-auth@beta"
    ];
    provider = {
      google = {
        models = [
          {
            "antigravity-claude-sonnet-4-5-thinking" = {
              name = "Claude Sonnet 4.5 Thinking";
              # FIX: Added semicolons after values inside the sets
              limit = {
                context = 200000;
                output = 64000;
              };
              modalities = {
                input = ["text" "image" "pdf"];
                output = ["text"];
              };
              variants = {
                low = {thinkingConfig = {thinkingBudget = 8192;};};
                max = {thinkingConfig = {thinkingBudget = 32768;};};
              };
            };
          }
        ];
      };
    };

    # You can add other standard OpenCode settings here
    # "theme" = "dark";
  };

  # Configure oh-my-opencode.json (The plugin settings)
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";

    # LSP Configuration
    lsp = {
      nixd = {
        command = ["${pkgs.nixd}/bin/nixd"];
        extensions = [".nix"];
        priority = 100;
        initializationOptions = {
          formatting = {
            command = ["${pkgs.alejandra}/bin/alejandra"];
          };
          nixos = {
            expr = "(builtins.getFlake \"${config.home.homeDirectory}/dotfiles/nixos\").nixosConfigurations.proartp16.options";
          };
        };
      };
      omnisharp = {
        command = [
          "${pkgs.omnisharp-roslyn}/bin/OmniSharp"
          "-lsp"
        ];
        extensions = [".cs" ".csx"];
        priority = 100;
        initializationOptions = {
          enableRoslynAnalyzers = true;
          analyzeOpenDocumentsOnly = false;
          enableImportCompletion = true;
          sdk = {
            includePrereleases = false;
          };
        };
      };
    };
  };
}
