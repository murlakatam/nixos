# oh-my-claudecode: multi-agent plugin for Claude Code, loaded in every session.
# The consumer passes the package, because shared modules take no flake inputs.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.oh-my-claudecode;
  # The plugin runs a bare `node`, which is not on PATH. Pin the package's own.
  node = lib.findFirst (d: lib.getName d == "nodejs") pkgs.nodejs_24 cfg.package.buildInputs;
  package = cfg.package.overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        r=$out/lib/node_modules/oh-my-claude-sisyphus
        substituteInPlace $r/hooks/hooks.json $r/.mcp.json \
          --replace-fail '"command": "node"' '"command": "${node}/bin/node"'
        substituteInPlace $r/dist/hud/index.js $r/dist/notifications/reply-listener.js \
          --replace-fail 'spawn("node",' 'spawn("${node}/bin/node",'
        substituteInPlace $r/dist/features/rate-limit-wait/daemon.js \
          --replace-fail "spawn('node'," "spawn('${node}/bin/node',"
        substituteInPlace $r/bridge/cli.cjs \
          --replace-fail 'spawn)("node", ["-e", daemonScript]' 'spawn)("${node}/bin/node", ["-e", daemonScript]'
        substituteInPlace $r/dist/utils/omc-cli-rendering.js $r/bridge/cli.cjs $r/bridge/team.js $r/bridge/runtime-cli.cjs \
          --replace-fail 'node "$CLAUDE_PLUGIN_ROOT"/bridge/cli.cjs' '${node}/bin/node "$CLAUDE_PLUGIN_ROOT"/bridge/cli.cjs'
      '';
  });
  pluginDir = "${package}/lib/node_modules/oh-my-claude-sisyphus";
in {
  imports = [../ai-permissions ../claude-code];

  options.dotfiles.oh-my-claudecode = {
    enable = lib.mkEnableOption "the oh-my-claudecode plugin and omc CLI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "oh-my-claudecode package, e.g. from numtide/llm-agents.nix.";
    };
    globalInstructions.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Append OMC's guide to ~/.claude/CLAUDE.md.";
    };
    hud.enable = lib.mkEnableOption "the OMC HUD script (deployed only; the status line is not changed)";
    herdrShim.enable = lib.mkEnableOption "running omc team, ralph and ultrawork in a visible herdr tab";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.packages = [package];
      home.sessionVariables = {
        OMC_PLUGIN_ROOT = pluginDir;
        OMC_MODEL_HIGH = "opus";
      };
      # OMC's hooks inherit Claude Code's environment, not a login shell's.
      ai.claudeCode.pluginDirs = [pluginDir];
      ai.claudeCode.extraEnv = {
        OMC_PLUGIN_ROOT = pluginDir;
        OMC_MODEL_HIGH = "opus";
        # Keyword matching starts modes on negated or generated prompts.
        OMC_SKIP_HOOKS = "keyword-detector";
      };
      home.file.".claude/.omc-config.json".text = builtins.toJSON {
        taskTool = "builtin";
        taskToolConfig = {
          injectInstructions = true;
          useMcp = false;
        };
        team.ops = {
          maxAgents = 3;
          defaultAgentType = "claude";
          monitorIntervalMs = 30000;
          shutdownTimeoutMs = 15000;
        };
        setupCompleted = "2026-04-21T00:00:00Z";
        setupVersion = cfg.package.version;
      };
    }

    (lib.mkIf cfg.globalInstructions.enable {
      ai.claudeCode.extraGlobalInstructions = [(builtins.readFile "${pluginDir}/docs/CLAUDE.md")];
    })

    (lib.mkIf cfg.hud.enable {
      home.file.".claude/hud/omc-hud.mjs".source = "${pluginDir}/scripts/lib/hud-wrapper-template.txt";
      home.file.".claude/hud/lib/config-dir.mjs".source = "${pluginDir}/scripts/lib/config-dir.mjs";
    })

    (lib.mkIf cfg.herdrShim.enable {
      home.packages = [
        (lib.hiPrio (import ./herdr-shim.nix {
          inherit pkgs package;
        }))
      ];
    })
  ]);
}
