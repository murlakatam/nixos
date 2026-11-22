# Claude Code user setup shared by every host: global memory (~/.claude/CLAUDE.md),
# a sensitive-file deny baseline, notification + model-label hooks, generic settings.
#
# Options (always declared, so contributors evaluate on any host):
#   ai.claudeCode.memory.sections.<name>   {enable, order, text}, rendered by (order, name)
#   ai.claudeCode.extraGlobalInstructions  blocks appended after the sections
#
# dotfiles.claude-code.enable writes CLAUDE.md and contributes to ai.permissions.*
# and ai.claudeCode.{settings,extraEnv}. Those reach settings.json through the host's
# writer (dotfiles.ai-permissions.enable, or a host's own writer reading the same options).
# The generic sections sit at orders 100-150; hosts add theirs (e.g. order 300) or
# switch one off with `ai.claudeCode.memory.sections.<name>.enable = false`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.claude-code;
  mcfg = config.ai.claudeCode;
  jq = "${pkgs.jq}/bin/jq";

  sections = lib.sort (a: b:
    if a.order == b.order
    then a.name < b.name
    else a.order < b.order)
  (lib.filter (s: s.enable) (lib.mapAttrsToList (name: s: s // {inherit name;}) mcfg.memory.sections));
  ensureNl = t:
    if lib.hasSuffix "\n" t
    then t
    else t + "\n";
  memoryText =
    lib.concatMapStringsSep "\n" (s: ensureNl s.text) sections
    + lib.concatMapStrings (b: "\n" + b) mcfg.extraGlobalInstructions;

  generic = lib.imap0 (i: name: {
    inherit name;
    value = {
      order = lib.mkDefault (100 + 10 * i);
      text = lib.mkDefault (builtins.readFile (./memory + "/${name}.md"));
    };
  }) ["core-principles" "small-changes" "think-before-coding" "simplicity-first" "surgical-changes" "goal-driven-execution"];

  # Desktop popup. No-op inside herdr / the Herdr app (they toast), without a
  # display (headless), and it never fails the hook.
  notify = body:
    pkgs.writeShellScript "claude-notify" ''
      [ -n "''${HERDR_ENV:-}''${HC_TERMINAL_ID:-}" ] && exit 0
      [ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ] || exit 0
      ${pkgs.libnotify}/bin/notify-send 'Claude Code' '${body}' --icon=dialog-information 2>/dev/null
      exit 0
    '';

  # Shows "claude · <model>" on the pane (herdr TUI) or as a `model` label on the
  # terminal (Herdr app / hc). Runs on Stop (catches /model) and UserPromptSubmit.
  modelLabel = pkgs.writeShellScript "claude-model-label" ''
    agent_id=$(${jq} -r '.agent_id // empty' 2>/dev/null) || true
    [ -z "$agent_id" ] || exit 0
    model=$(${jq} -r '.model // empty' "''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null) || exit 0
    [ -n "$model" ] || exit 0
    short="''${model#claude-}"
    if [ "''${HERDR_ENV:-}" = "1" ] && [ -n "''${HERDR_PANE_ID:-}" ]; then
      herdr pane report-metadata "$HERDR_PANE_ID" --source "herdr:claude-model-display" \
        --display-agent "claude · $short" >/dev/null 2>&1
    elif [ -n "''${HC_TERMINAL_ID:-}" ] && command -v hc >/dev/null 2>&1; then
      hc label "$HC_TERMINAL_ID" "model=$short" >/dev/null 2>&1
    fi
    exit 0
  '';
in {
  options.ai.claudeCode = {
    memory.sections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Include this section.";
          };
          order = lib.mkOption {
            type = lib.types.int;
            default = 500;
            description = "Position; lower comes first, ties sorted by name.";
          };
          text = lib.mkOption {
            type = lib.types.lines;
            description = "Markdown block.";
          };
        };
      });
      default = {};
      description = "Blocks of ~/.claude/CLAUDE.md.";
    };
    extraGlobalInstructions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra content blocks appended to ~/.claude/CLAUDE.md after the sections.";
    };
  };

  options.dotfiles.claude-code = {
    enable = lib.mkEnableOption "the shared Claude Code user setup";
    memory.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Write ~/.claude/CLAUDE.md from ai.claudeCode.memory.sections.";
    };
    notify.enable = lib.mkEnableOption "desktop notifications on Stop and Notification (no-op in herdr or headless)";
    modelLabel.enable = lib.mkEnableOption "the model label on the herdr pane / hc terminal";
    statusLine = {
      enable = lib.mkEnableOption "ccstatusline as the status line (ccstatusline must be installed)";
      padding = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "statusLine.padding.";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Pinned ccstatusline. When set, the status line runs it by store path and this module installs its config. Null runs `ccstatusline` from PATH.";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      ai.claudeCode.memory.sections = lib.listToAttrs generic;
      home.file.".claude/CLAUDE.md" = lib.mkIf cfg.memory.enable {text = memoryText;};

      ai.permissions.denyPaths = [
        "**/secrets.toml"
        "**/secrets.*.toml"
        "**/.env"
        "**/.env.*"
      ];
      # Bash(*.env*) would also block `.envrc`, `process.env`, jq paths, ...
      ai.permissions.claudeCode.noBashDenyRoots = [".env"];
      # No Bash(*root*) for these: `~/.ssh/**` would give Bash(***), and agents
      # legitimately run `sops set` and `ssh`.
      ai.permissions.claudeCode.deny = lib.concatMap (p: ["Read(${p})" "Edit(${p})"]) [
        "~/.ssh/id_*"
        "~/.aws/credentials"
        "~/.aws/sso/cache/**"
        "~/.config/sops/age/**"
        "~/.gnupg/**"
        "~/.claude/.credentials.json"
        "~/.netrc"
      ];

      ai.claudeCode.settings.cleanupPeriodDays = lib.mkDefault 120;
      ai.claudeCode.extraEnv = {
        # Nix pins the claude-code package; the CLI's autoupdater would fight it.
        DISABLE_AUTOUPDATER = lib.mkDefault "1";
        CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = lib.mkDefault "1";
      };
    }
    (lib.mkIf cfg.statusLine.enable {
      ai.claudeCode.settings.statusLine = {
        type = "command";
        command =
          if cfg.statusLine.package != null
          then lib.getExe cfg.statusLine.package
          else "ccstatusline";
        inherit (cfg.statusLine) padding;
      };
      xdg.configFile."ccstatusline/settings.json" = lib.mkIf (cfg.statusLine.package != null) {
        source = ../../../homeManagerModules/ccstatusline/settings.json;
      };
    })
    (lib.mkIf cfg.notify.enable {
      ai.permissions.claudeCode.stopHooks = [
        {
          command = "${notify "Task completed"}";
          async = true;
        }
      ];
      ai.permissions.claudeCode.notificationHooks = [
        {
          command = "${notify "Waiting for your input"}";
          async = true;
        }
      ];
    })
    (lib.mkIf cfg.modelLabel.enable {
      ai.permissions.claudeCode.stopHooks = [
        {
          command = "${modelLabel}";
          async = true;
        }
      ];
      ai.permissions.claudeCode.userPromptSubmitHooks = [
        {
          command = "${modelLabel}";
          async = true;
        }
      ];
    })
  ]);
}
