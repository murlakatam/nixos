# obsidian-second-brain (MIT, github:eugeniughelbur/obsidian-second-brain) for Claude Code:
# the skill, a reviewed set of its slash commands, and its two passive hooks.
#
#   dotfiles.obsidian-second-brain = {
#     enable = true;
#     src = inputs.obsidian-second-brain; # flake = false input
#     vaultPath = "/home/me/docs/brain";
#   };
#
# Left out on purpose: the PostCompact agent (runs Claude with permission checks off), the MCP
# server, and commands that need paid API keys or send vault notes to third-party services.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.obsidian-second-brain;

  commands = [
    "idea-discovery"
    "obsidian-architect"
    "obsidian-board"
    "obsidian-board-hygiene"
    "obsidian-brainstorm"
    "obsidian-calendar"
    "obsidian-capture"
    "obsidian-challenge"
    "obsidian-checkin"
    "obsidian-connect"
    "obsidian-daily"
    "obsidian-decide"
    "obsidian-distill"
    "obsidian-emerge"
    "obsidian-export"
    "obsidian-find"
    "obsidian-graduate"
    "obsidian-health"
    "obsidian-ingest"
    "obsidian-init"
    "obsidian-learn"
    "obsidian-log"
    "obsidian-merge"
    "obsidian-panel"
    "obsidian-person"
    "obsidian-project"
    "obsidian-projects"
    "obsidian-recap"
    "obsidian-reconcile"
    "obsidian-recurring"
    "obsidian-review"
    "obsidian-save"
    "obsidian-synthesize"
    "obsidian-task"
    "obsidian-visualize"
    "obsidian-world"
    "vault-deep-synthesis"
  ];

  # The reviewed commands import only pyyaml outside the standard library.
  python = pkgs.python3.withPackages (ps: [ps.pyyaml]);

  # Upstream runs `uv run --directory SKILL_ROOT`, which can't create a venv in the read-only store.
  osbRun = pkgs.writeShellScriptBin "osb-run" ''
    cd "$1" || exit
    shift
    [ "$1" = python ] && shift
    exec ${python}/bin/python "$@"
  '';
  uvSed = ''-e 's#uv run --directory "SKILL_ROOT"#osb-run "SKILL_ROOT"#g' '';

  skillRoot = pkgs.runCommand "obsidian-second-brain-skill" {} ''
    mkdir -p $out
    cp -r ${cfg.src}/references ${cfg.src}/scripts ${cfg.src}/hooks ${cfg.src}/LICENSE $out/
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed ${uvSed} ${cfg.src}/SKILL.md > $out/SKILL.md
    ! grep -qF 'uv run --directory' $out/SKILL.md
  '';

  # Upstream doesn't say what to do when a dated heading is missing, and the model then attaches
  # the entry to the nearest line.
  anchorRule = pkgs.writeText "ingest-anchor-rule" "   - Missing anchor: if the dated heading an entry belongs under does not exist (in `index.md`, `log.md`, `Logs/` or the daily note), do not attach the entry to the nearest line. Create the heading in the file's own format at its chronological position between the neighbouring dates, put the entry under it, and say so in the report: file, heading created, position.\n";

  commandDir = pkgs.runCommand "obsidian-second-brain-commands" {} ''
    mkdir -p $out
    for name in ${lib.escapeShellArgs commands}; do
      ${pkgs.gnused}/bin/sed ${uvSed} ${cfg.src}/commands/$name.md > $out/$name.md
    done

    grep -qF 'REBUILD `index.md`' ${cfg.src}/commands/obsidian-ingest.md
    ${pkgs.gnused}/bin/sed ${uvSed} \
      -e '/^   - REBUILD `index.md`/r ${anchorRule}' \
      ${cfg.src}/commands/obsidian-ingest.md > $out/obsidian-ingest.md
    grep -qF 'Missing anchor:' $out/obsidian-ingest.md

    # "deep research" belongs to the research-router skill, so this one is explicit-only.
    grep -qF 'description: Vault-first deep research' ${cfg.src}/commands/research-deep.md
    grep -qF '"deep research", ' ${cfg.src}/commands/research-deep.md
    ${pkgs.gnused}/bin/sed ${uvSed} \
      -e 's#^description: Vault-first deep research#description: Explicit-only, reached via the research-router skill or /obsidian-research-deep. Vault-first deep research#' \
      -e 's#"deep research", ##' \
      -e 's#/research-deep#/obsidian-research-deep#g' \
      ${cfg.src}/commands/research-deep.md > $out/obsidian-research-deep.md

    ! grep -rqF 'uv run --directory' $out
  '';

  # Hooks get their tools and the vault path even in sessions started before the last switch.
  mkHook = script:
    pkgs.writeShellScript "osb-${script}" ''
      export OBSIDIAN_VAULT_PATH="''${OBSIDIAN_VAULT_PATH:-${cfg.vaultPath}}"
      export PATH=${lib.makeBinPath [python pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gnused]}:$PATH
      exec ${skillRoot}/hooks/${script}
    '';
in {
  imports = [../ai-permissions];

  options.dotfiles.obsidian-second-brain = {
    enable = lib.mkEnableOption "the obsidian-second-brain skill and commands";
    src = lib.mkOption {
      type = lib.types.path;
      description = "Source tree of obsidian-second-brain (a `flake = false` input).";
    };
    vaultPath = lib.mkOption {
      type = lib.types.str;
      example = "/home/me/docs/brain";
      description = "Absolute path of the vault the skill works on.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [osbRun];
    home.sessionVariables.OBSIDIAN_VAULT_PATH = cfg.vaultPath;

    home.file =
      {
        ".claude/skills/obsidian-second-brain".source = skillRoot;
        ".claude/skills/ingest/SKILL.md".text = ''
          ---
          name: ingest
          description: "Shortcut alias for the /obsidian-ingest command. Use when the user types /ingest or another skill invokes `ingest` with a source path."
          ---

          # Skill: ingest

          Read `~/.claude/commands/obsidian-ingest.md` and execute it, with any arguments as its source.
        '';
      }
      // lib.listToAttrs (map (name:
        lib.nameValuePair ".claude/commands/${name}.md" {source = "${commandDir}/${name}.md";})
      (commands ++ ["obsidian-research-deep"]));

    ai.permissions.claudeCode = {
      # A leading // makes the path absolute in Claude Code permission rules.
      allowedTools = [
        "Read(/${cfg.vaultPath}/**)"
        "Edit(/${cfg.vaultPath}/**)"
      ];
      sessionStartHooks = [{command = "${mkHook "load_vault_context.sh"}";}];
      postToolUseHooks = [
        {
          matcher = "Write|Edit";
          command = "${mkHook "validate-ai-first.sh"}";
        }
      ];
    };
  };
}
