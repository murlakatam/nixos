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
    pkgs.csharp-ls # C# Language Server
    pkgs.dotnetCorePackages.sdk_8_0
  ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    plugin = [
      "file://${pkgs.oh-my-opencode}/share/oh-my-opencode/dist/index.js"
      "opencode-antigravity-auth@beta"
    ];
    provider = {
      google = {
        models = {
          "antigravity-claude-sonnet-4-5" = {
            name = "Claude Sonnet 4.5";
            limit = {
              context = 200000;
              output = 64000;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
          };
          "antigravity-claude-sonnet-4-5-thinking" = {
            name = "Claude Sonnet 4.5 Thinking";
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
          "antigravity-claude-opus-4-5-thinking" = {
            name = "Claude Opus 4.5 Thinking";
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
          "antigravity-gemini-3-pro" = {
            name = "Gemini 3 Pro Thinking";
            limit = {
              context = 200000;
              output = 64000;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
            variants = {
              low = {thinkingLevel = "low";};
              high = {thinkingLevel = "high";};
            };
          };
          "antigravity-gemini-3-flash" = {
            name = "Gemini 3 Flash";
            limit = {
              context = 200000;
              output = 64000;
            };
            modalities = {
              input = ["text" "image" "pdf"];
              output = ["text"];
            };
            variants = {
              low = {thinkingLevel = "low";};
              medium = {thinkingLevel = "medium";};
              high = {thinkingLevel = "high";};
            };
          };
        };
      };
    };

    # You can add other standard OpenCode settings here
    # "theme" = "dark";
  };

  # Configure oh-my-opencode.json (The plugin settings)
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    "frontend-ui-ux-engineer" = {model = "google/antigravity-gemini-3-pro-high";}; # Updated ID
    "document-writer" = {model = "google/antigravity-gemini-3-flash-high";};
    "multimodal-looker" = {model = "google/antigravity-gemini-3-flash";};
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
      csharp-ls = {
        command = ["${pkgs.csharp-ls}/bin/csharp-ls"];
        extensions = [".cs"];
        priority = 100;
        initializationOptions = {
          # csharp-ls usually detects the SDK automatically via the PATH,
          # but usually requires 'dotnet' to be in the environment.
          # Since you have dotnetCorePackages.sdk_8_0 in home.packages, it should work.
        };
      };
    };
  };
}
