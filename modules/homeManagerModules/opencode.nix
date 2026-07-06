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

  # Declaratively deploy the custom "nixos-rebuild" agent skill.
  # This teaches agents to rebuild ONLY via the token-efficient `nixos-rebuild-ai`
  # wrapper and nothing else.
  xdg.configFile."opencode/skill/nixos-rebuild" = {
    source = ./opencode-skills/nixos-rebuild;
    recursive = true;
  };

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    theme = "catppuccin-macchiato";
    plugin = [
      "file://${pkgs.oh-my-opencode}/share/oh-my-opencode/dist/index.js"
    ];
    # OpenCode Zen is a built-in provider — authenticate via `/connect` in the TUI.
    # Models are referenced as `opencode/<model-id>` (see https://opencode.ai/docs/zen/).
  };

  # Configure oh-my-opencode.json (The plugin settings)
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
    agents = {
      "Sisyphus" = {
        description = "Primary orchestrator agent with powerful AI capabilities";
        model = "opencode/claude-opus-4-8";
      };
      "OpenCode-Builder" = {
        description = "Default build agent for development tasks";
        model = "opencode/gpt-5.5";
      };
      "Planner-Sisyphus" = {
        description = "Strategic planning agent with minimal creativity";
        model = "opencode/claude-opus-4-8";
      };
      "oracle" = {
        description = "Expert technical advisor for architecture decisions and code analysis";
        model = "opencode/gpt-5.5";
      };
      "librarian" = {
        description = "Multi-repository analysis, official docs, and implementation examples";
        model = "opencode/claude-sonnet-4-6";
        prompt_append = "\n---\n\n**Important:** The EXTERNAL RESOURCES section in AGENTS.md documents key dependencies, references, and documentation to assist you in providing accurate and context-aware responses. Read this section carefully before you begin.";
      };
      "explore" = {
        description = "Fast agent for codebase exploration and pattern matching";
        model = "opencode/gemini-3.5-flash";
      };
      "frontend-ui-ux-engineer" = {
        description = "Designer-turned-developer for stunning UI/UX implementation";
        model = "opencode/claude-sonnet-4-6";
      };
      "document-writer" = {
        description = "Technical writing expert for documentation and guides";
        model = "opencode/claude-sonnet-4-6";
      };
      "multimodal-looker" = {
        description = "Analyzes PDFs, images, diagrams beyond raw text";
        model = "opencode/gemini-3.5-flash";
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
