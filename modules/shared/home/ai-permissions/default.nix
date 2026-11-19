# AI tool permissions: one option set that every module contributes to.
#
# Options (always declared, so contributors evaluate on any host):
#   ai.permissions.claudeCode.allowedTools        Claude Code permissions.allow patterns
#   ai.permissions.claudeCode.excludedCommands    sandbox.excludedCommands names
#   ai.permissions.claudeCode.<event>Hooks        hooks per event ({command}, tool hooks {matcher, command})
#   ai.permissions.claudeCode.ownedHookPatterns   regexes: hooks written elsewhere that the writer replaces
#   ai.permissions.denyPaths                      sensitive globs, denied to Read/Edit/Bash
#   ai.permissions.openCode.{bash,plugins}        read by the host's OpenCode module
#
# dotfiles.ai-permissions.enable turns on the writer: at activation it merges
# these into the live ~/.claude/settings.json. Claude rewrites that file itself
# (model, theme, ...), so it isn't a store symlink. The writer only replaces
# what it wrote last time (kept in a state file) plus hooks matching
# ownedHookPatterns; every other key and entry is preserved. It validates the
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

  hookOpt = desc:
    lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options.command = lib.mkOption {
          type = lib.types.str;
          description = "Hook command line.";
        };
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
  };
  toolEvents = {
    preToolUseHooks = "PreToolUse";
    postToolUseHooks = "PostToolUse";
  };

  hookEntry = h: {
    type = "command";
    inherit (h) command;
    timeout = cfg.claudeCode.hookTimeout;
  };
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
  # (`**/.env` and `**/.env.*` both give `*.env*`).
  bashRoot = p: lib.removeSuffix "*" (lib.removeSuffix ".*" (lib.last (lib.splitString "/" p)));
  deny =
    lib.concatMap (p: ["Read(${p})" "Edit(${p})"]) pcfg.denyPaths
    ++ map (r: "Bash(*${r}*)") (lib.unique (map bashRoot pcfg.denyPaths));

  managed = pkgs.writeText "ai-permissions-claude.json" (builtins.toJSON {
    allow = lib.unique ccfg.allowedTools;
    inherit deny hooks hookCommands;
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
      | if $m.excluded != null
        then .sandbox.excludedCommands = ((((.sandbox.excludedCommands // []) - ($p.excluded // [])) + $m.excluded) | unique)
        else . end
    ' "$f" > "$tmp" 2>/dev/null || warn "merge failed"
    ${jq} -e 'type == "object"' "$tmp" >/dev/null 2>&1 || warn "merge produced invalid JSON"
    chmod --reference="$f" "$tmp" 2>/dev/null || true
    cmp -s "$tmp" "$f" && rm -f "$tmp" || mv -f "$tmp" "$f" || warn "cannot replace file"
    ${jq} '{allow, deny, hooks: .hookCommands, events: (.hooks | keys), excluded}' ${managed} > "$prev.tmp" \
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
      preToolUseHooks = toolHookOpt "PreToolUse";
      postToolUseHooks = toolHookOpt "PostToolUse";
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
