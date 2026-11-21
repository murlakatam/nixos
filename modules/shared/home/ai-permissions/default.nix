# AI tool permissions: one option set that every module contributes to.
#
# Options (always declared, so contributors evaluate on any host):
#   ai.permissions.claudeCode.allowedTools        Claude Code permissions.allow patterns
#   ai.permissions.claudeCode.excludedCommands    sandbox.excludedCommands names
#   ai.permissions.claudeCode.<event>Hooks        hooks per event ({command}, tool hooks {matcher, command})
#   ai.permissions.claudeCode.ownedHookPatterns   regexes: hooks written elsewhere that the writer replaces
#   ai.permissions.claudeCode.deny                raw permissions.deny rules (no Bash expansion)
#   ai.permissions.denyPaths                      sensitive globs, denied to Read/Edit/Bash
#   ai.claudeCode.settings                        other settings.json keys, owned per leaf
#   ai.claudeCode.extraEnv                        settings.json `env` entries, owned per key
#   ai.permissions.openCode.{bash,plugins}        read by the host's OpenCode module
#
# dotfiles.ai-permissions.enable turns on the writer: at activation it merges
# these into the live ~/.claude/settings.json. Claude rewrites that file itself
# (model, theme, ...), so it isn't a store symlink. The writer only replaces
# what it wrote last time (kept in a state file) plus hooks matching
# ownedHookPatterns, and the leaves of ai.claudeCode.settings/extraEnv it set
# (a user's own `env.FOO` or `model` stays); every other key and entry is preserved. It validates the
# result before replacing the file and never fails activation.
{
  config,
  lib,
  pkgs,
  ...
}: let
  pcfg = config.ai.permissions;
  ccfg = pcfg.claudeCode;
  cfg = config.dotfiles.ai-permissions;

  asyncOpt = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Run the hook in the background (written as `async: true`).";
  };
  hookOpt = desc:
    lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options.command = lib.mkOption {
          type = lib.types.str;
          description = "Hook command line.";
        };
        options.async = asyncOpt;
      });
      default = [];
      description = "${desc} hooks merged into Claude Code's settings.json.";
    };
  toolHookOpt = desc:
    lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          matcher = lib.mkOption {
            type = lib.types.str;
            description = "Tool name to match (e.g. \"Bash\").";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Hook command line.";
          };
          async = asyncOpt;
        };
      });
      default = [];
      description = "${desc} hooks merged into Claude Code's settings.json.";
    };

  # option name -> settings.json event
  plainEvents = {
    sessionStartHooks = "SessionStart";
    sessionEndHooks = "SessionEnd";
    stopHooks = "Stop";
    subagentStopHooks = "SubagentStop";
    postCompactHooks = "PostCompact";
    userPromptSubmitHooks = "UserPromptSubmit";
    permissionRequestHooks = "PermissionRequest";
    notificationHooks = "Notification";
  };
  toolEvents = {
    preToolUseHooks = "PreToolUse";
    postToolUseHooks = "PostToolUse";
  };

  hookEntry = h:
    {
      type = "command";
      inherit (h) command;
      timeout = cfg.claudeCode.hookTimeout;
    }
    // lib.optionalAttrs h.async {async = true;};
  # One group per hook (matcher "*"), so removing one never touches another.
  plainGroups = hs:
    map (h: {
      matcher = "*";
      hooks = [(hookEntry h)];
    })
    hs;
  toolGroups = hs:
    lib.mapAttrsToList (matcher: g: {
      inherit matcher;
      hooks = map hookEntry g;
    }) (lib.groupBy (h: h.matcher) hs);

  hooks = lib.filterAttrs (_: v: v != []) (
    lib.mapAttrs' (opt: ev: lib.nameValuePair ev (plainGroups ccfg.${opt})) plainEvents
    // lib.mapAttrs' (opt: ev: lib.nameValuePair ev (toolGroups ccfg.${opt})) toolEvents
  );
  hookCommands =
    lib.concatMap (opt: map (h: h.command) ccfg.${opt})
    (lib.attrNames plainEvents ++ lib.attrNames toolEvents);

  # denyPaths -> Read(p), Edit(p), plus one Bash(*root*) per basename root
  # (`**/.env` and `**/.env.*` both give `*.env*`), except noBashDenyRoots.
  bashRoot = p: lib.removeSuffix "*" (lib.removeSuffix ".*" (lib.last (lib.splitString "/" p)));
  deny =
    lib.concatMap (p: ["Read(${p})" "Edit(${p})"]) pcfg.denyPaths
    ++ map (r: "Bash(*${r}*)") (lib.subtractLists ccfg.noBashDenyRoots (lib.unique (map bashRoot pcfg.denyPaths)))
    ++ ccfg.deny;

  # ai.claudeCode.settings (+ extraEnv as `env`), and its leaf paths: the writer
  # owns each leaf, not whole objects, so Claude's own keys next to them stay.
  settings =
    lib.recursiveUpdate config.ai.claudeCode.settings
    (lib.optionalAttrs (config.ai.claudeCode.extraEnv != {}) {env = config.ai.claudeCode.extraEnv;});
  leafPaths = prefix: v:
    if lib.isAttrs v
    then lib.concatLists (lib.mapAttrsToList (k: x: leafPaths (prefix ++ [k]) x) v)
    else [prefix];

  managed = pkgs.writeText "ai-permissions-claude.json" (builtins.toJSON {
    allow = lib.unique ccfg.allowedTools;
    inherit deny hooks hookCommands settings;
    settingsPaths = leafPaths [] settings;
    patterns = ccfg.ownedHookPatterns;
    excluded =
      if cfg.claudeCode.writeSandboxExcludes
      then lib.unique ccfg.excludedCommands
      else null;
  });

  jq = "${pkgs.jq}/bin/jq";
  writer = pkgs.writeShellScript "ai-permissions-claude-settings" ''
    set -u
    f="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-ai-permissions"
    prev="$state/owned.json"
    tmp="$f.ai-permissions-tmp"
    warn() { echo "ai-permissions: $1; $f left unchanged" >&2; rm -f "$tmp"; exit 0; }
    mkdir -p "$state" "$(dirname "$f")" || warn "cannot create state dir"
    [ -s "$f" ] || echo '{}' > "$f" || warn "cannot create settings file"
    [ -s "$prev" ] || echo '{}' > "$prev"
    ${jq} -e 'type == "object"' "$f" >/dev/null 2>&1 || warn "not a JSON object"
    ${jq} --slurpfile m ${managed} --slurpfile prev "$prev" '
      ($m[0]) as $m | ($prev[0]) as $p
      | (($p.hooks // []) + $m.hookCommands) as $mine
      | def owned: (.command // "") as $c
          | any($mine[]; . == $c) or any($m.patterns[]; . as $re | $c | test($re));
        def clean: map(.hooks |= map(select(owned | not))) | map(select((.hooks | length) > 0));
      .permissions = (.permissions // {})
      | .permissions.allow = ((((.permissions.allow // []) - ($p.allow // [])) + $m.allow) | unique)
      | if ($m.deny | length) > 0 or (.permissions.deny // null) != null
        then .permissions.deny = ((((.permissions.deny // []) - ($p.deny // [])) + $m.deny) | unique)
        else . end
      | .hooks = (.hooks // {})
      | reduce (($m.hooks | keys) + (($p.events // []) - ($m.hooks | keys)))[] as $ev (.;
          .hooks[$ev] = (((.hooks[$ev] // []) | clean) + ($m.hooks[$ev] // []))
          | if (.hooks[$ev] | length) == 0 then del(.hooks[$ev]) else . end)
      | if (.hooks | length) == 0 then del(.hooks) else . end
      | reduce ((($p.settings // []) - $m.settingsPaths)[]) as $sp (.;
          try (delpaths([$sp])
            | if ($sp | length) > 1 and getpath($sp[:-1]) == {} then delpaths([$sp[:-1]]) else . end)
          catch .)
      | reduce $m.settingsPaths[] as $sp (.; setpath($sp; $m.settings | getpath($sp)))
      | if $m.excluded != null
        then .sandbox.excludedCommands = ((((.sandbox.excludedCommands // []) - ($p.excluded // [])) + $m.excluded) | unique)
        else . end
    ' "$f" > "$tmp" 2>/dev/null || warn "merge failed"
    ${jq} -e 'type == "object"' "$tmp" >/dev/null 2>&1 || warn "merge produced invalid JSON"
    chmod --reference="$f" "$tmp" 2>/dev/null || true
    cmp -s "$tmp" "$f" && rm -f "$tmp" || mv -f "$tmp" "$f" || warn "cannot replace file"
    ${jq} '{allow, deny, hooks: .hookCommands, events: (.hooks | keys), excluded, settings: .settingsPaths}' ${managed} > "$prev.tmp" \
      && mv -f "$prev.tmp" "$prev"
    exit 0
  '';
in {
  options.ai.permissions = {
    claudeCode = {
      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tool patterns added to Claude Code's permissions.allow.";
      };
      excludedCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Command names for Claude Code's sandbox.excludedCommands (written only with writeSandboxExcludes).";
      };
      sessionStartHooks = hookOpt "SessionStart";
      sessionEndHooks = hookOpt "SessionEnd";
      stopHooks = hookOpt "Stop";
      subagentStopHooks = hookOpt "SubagentStop";
      postCompactHooks = hookOpt "PostCompact";
      userPromptSubmitHooks = hookOpt "UserPromptSubmit";
      permissionRequestHooks = hookOpt "PermissionRequest";
      notificationHooks = hookOpt "Notification";
      preToolUseHooks = toolHookOpt "PreToolUse";
      postToolUseHooks = toolHookOpt "PostToolUse";
      deny = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["Read(~/.ssh/id_*)"];
        description = "Raw permissions.deny rules, for paths where denyPaths' Bash(*root*) rule would be wrong.";
      };
      noBashDenyRoots = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [".env"];
        description = "denyPaths basename roots that get Read/Edit rules but no Bash(*root*) rule, because the substring matches too many commands.";
      };
      ownedHookPatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["/nix/store/[^ ]*my-tool"];
        description = ''
          jq regexes. Existing hooks whose command matches one are treated as
          the writer's own and replaced, e.g. hooks an older module wrote.
        '';
      };
    };
    denyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["**/.env" "**/.env.*"];
      description = "Sensitive globs; each becomes Read(p), Edit(p) and Bash(*<basename>*) deny rules.";
    };
    openCode = {
      bash = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "OpenCode permission.bash rules (pattern -> allow/ask/deny), read by the host's OpenCode module.";
      };
      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "OpenCode plugin URIs, read by the host's OpenCode module.";
      };
    };
  };

  options.ai.claudeCode = {
    settings = lib.mkOption {
      type = (pkgs.formats.json {}).type;
      default = {};
      example = {cleanupPeriodDays = 120;};
      description = "Other settings.json keys. The writer owns each leaf it sets and removes the ones it no longer sets.";
    };
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Env vars merged into settings.json `env`, one owned leaf each.";
    };
  };

  options.dotfiles.ai-permissions = {
    enable = lib.mkEnableOption "merging ai.permissions.claudeCode into the live ~/.claude/settings.json at activation";
    claudeCode.hookTimeout = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Timeout (seconds) written on every hook.";
    };
    claudeCode.writeSandboxExcludes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also write excludedCommands to sandbox.excludedCommands.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.aiPermissionsClaudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] "${writer}";
  };
}
