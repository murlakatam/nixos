# kungfu (github:denyzhirkov/kungfu, MIT): local code index, call graph and
# git history for coding agents, used through its CLI.
#
# Not the upstream Claude plugin: its only extra is an MCP server, and
# `kungfu mcp` fixes its project root at start, so one server serves one repo.
# What it gives instead:
#   - the patched package (./package.nix);
#   - a PostToolUse hook that reindexes each edited file;
#   - the `kungfu` skill (../skills/kungfu, needs dotfiles.skills.enable;
#     host text through dotfiles.skills.extraSections.kungfu) and a short
#     always-on pointer to it in the global CLAUDE.md;
#   - Bash(kungfu *) allowed (`update` is patched out).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.kungfu;
in {
  imports = [../ai-permissions ../claude-code];

  options.dotfiles.kungfu = {
    enable = lib.mkEnableOption "kungfu, its reindex hook and skill";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix {};
      description = "kungfu package.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    ai.claudeCode.extraGlobalInstructions = [
      ''
        ## kungfu

        For callers/callees, what a change breaks, module coupling, symbol or
        file history, or concept search with no name to grep for, use the
        `kungfu` skill (the `kungfu` CLI). Grep stays right for literal strings.
      ''
    ];

    home.file.".claude/hooks/kungfu-reindex.sh" = {
      text = ''
        #!/usr/bin/env bash
        ${pkgs.jq}/bin/jq -r '.tool_input.file_path // empty' \
          | xargs -I{} ${lib.getExe cfg.package} index --only {} >/dev/null 2>&1 || true
      '';
      executable = true;
    };

    ai.permissions.claudeCode = {
      allowedTools = ["Bash(kungfu *)"];
      postToolUseHooks = [
        {
          matcher = "Edit|Write|MultiEdit|NotebookEdit";
          command = "${config.home.homeDirectory}/.claude/hooks/kungfu-reindex.sh";
        }
      ];
    };
  };
}
