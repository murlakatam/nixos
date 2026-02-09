{
  pkgs,
  osConfig,
  dotfilesPath,
  ...
}: {
  # check the overlays for the packages build/installation
  home.packages = [
    pkgs.dotnetCorePackages.sdk_8_0
  ];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    theme = "catppuccin-macchiato";
    plugin = [
      "file://${pkgs.oh-my-opencode}/share/oh-my-opencode/dist/index.js"
      "opencode-antigravity-auth@latest"
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
          "antigravity-claude-opus-4-6-thinking" = {
            name = "Claude Opus 4.6 Thinking";
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
    agents = {
      "Sisyphus" = {
        description = "Primary orchestrator agent with powerful AI capabilities";
        model = "google/antigravity-claude-opus-4-5-thinking";
      };
      "OpenCode-Builder" = {
        description = "Default build agent for development tasks";
        model = "google/antigravity-claude-opus-4-5-thinking";
      };
      "Planner-Sisyphus" = {
        description = "Strategic planning agent with minimal creativity";
        model = "google/antigravity-claude-opus-4-5-thinking";
      };
      "oracle" = {
        description = "Expert technical advisor for architecture decisions and code analysis";
        model = "github-copilot/gpt-5.2";
      };
      "librarian" = {
        description = "Multi-repository analysis, official docs, and implementation examples";
        model = "google/antigravity-claude-sonnet-4-5";
        prompt_append = "\n---\n\n**Important:** The EXTERNAL RESOURCES section in AGENTS.md documents key dependencies, references, and documentation to assist you in providing accurate and context-aware responses. Read this section carefully before you begin.";
      };
      "explore" = {
        description = "Fast agent for codebase exploration and pattern matching";
        model = "google/antigravity-gemini-3-flash";
      };
      "frontend-ui-ux-engineer" = {
        description = "Designer-turned-developer for stunning UI/UX implementation";
        model = "google/antigravity-gemini-3-pro";
      };
      "document-writer" = {
        description = "Technical writing expert for documentation and guides";
        model = "google/antigravity-gemini-3-pro";
      };
      "multimodal-looker" = {
        description = "Analyzes PDFs, images, diagrams beyond raw text";
        model = "google/antigravity-gemini-3-flash";
      };
    };

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
            expr = "(builtins.getFlake \"${dotfilesPath}\").nixosConfigurations.${osConfig.networking.hostName}.options";
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

    "ralph_loop" = {
      enabled = true;
      default_max_iterations = 30;
      "state_dir" = ".opencode/";
    };
  };
}
