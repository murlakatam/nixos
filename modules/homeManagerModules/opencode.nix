{
  pkgs,
  config,
  ...
}: {
  # check the overlays for the packages build/installation
  home.packages = [
    pkgs.opencode # The editor
    pkgs.oh-my-opencode # The OmO plugin
  ];

  # 2. Configure opencode.json (To load the plugin)
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    # Point to the exact path of the plugin in the Nix store
    plugin = [
      "file://${pkgs.oh-my-opencode}/share/oh-my-opencode/dist/index.js"
    ];

    # You can add other standard OpenCode settings here
    # "theme" = "dark";
  };

  # 3. Configure oh-my-opencode.json (The plugin settings)
  # This translates the JSON example you provided into Nix syntax
  #xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
  #  "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
  #
  #  # --- Google Auth ---
  #  # Set to false if using the external 'opencode-antigravity-auth' plugin (Recommended)
  #  # Set to true to use built-in Antigravity OAuth
  #  google_auth = false;
  #
  #  # --- Disabled Hooks ---
  #  # Add hooks here to disable them
  #  disabled_hooks = [
  #    # "startup-toast"
  #    # "auto-update-checker"
  #  ];
  #
  #  # --- Disabled MCPs ---
  #  # Disable default MCPs if you don't want them
  #  disabled_mcps = [
  #    # "context7"
  #    # "websearch_exa"
  #  ];
  #
  #  # --- Agent Configuration ---
  #  agents = {
  #    # Example: Customize the 'explore' agent
  #    explore = {
  #      model = "anthropic/claude-haiku-4-5";
  #      temperature = 0.5;
  #      permission = {
  #        edit = "deny";
  #        bash = "ask";
  #        webfetch = "allow";
  #      };
  #    };
  #
  #    # Example: Disable the 'frontend-ui-ux-engineer' agent
  #    frontend-ui-ux-engineer = {
  #      disable = true;
  #    };
  #
  #    # Example: Sisyphus (Orchestrator) settings
  #    Sisyphus = {
  #      model = "anthropic/claude-sonnet-4";
  #      temperature = 0.3;
  #    };
  #  };
  #
  #  # --- Sisyphus Feature Flags ---
  #  sisyphus_agent = {
  #    disabled = false;
  #    default_builder_enabled = false; # Set true to enable Builder-Sisyphus
  #    planner_enabled = true;
  #    replace_plan = true;
  #  };
  #
  #  # --- Experimental Features ---
  #  experimental = {
  #    aggressive_truncation = false;
  #    auto_resume = true;
  #    truncate_all_tool_outputs = true;
  #  };
  #};
}
