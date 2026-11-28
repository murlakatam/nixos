# Generic Claude Code skills: ./<name>/SKILL.md -> ~/.claude/skills/<name>/SKILL.md.
# Host-specific text stays in the host's own repo and is appended through
# `dotfiles.skills.extraSections.<name>`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.skills;

  allSkills = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./.));
  enabled = lib.filter (n:
    !(builtins.elem n cfg.exclude)
    && (n != "build-a-demo" || cfg.showboatPackage != null)
    && (n != "kungfu" || config.dotfiles.kungfu.enable))
  allSkills;
  has = n: builtins.elem n enabled;

  skillText = n:
    builtins.readFile (./. + "/${n}/SKILL.md")
    + lib.optionalString (cfg.extraSections ? ${n}) "\n${cfg.extraSections.${n}}";
in {
  imports = [../ai-permissions ../kungfu];

  options.dotfiles.skills = {
    enable = lib.mkEnableOption "the shared generic Claude Code skills";
    exclude = lib.mkOption {
      type = lib.types.listOf (lib.types.enum allSkills);
      default = [];
      description = "Shared skills this host doesn't install.";
    };
    extraSections = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      example = {output-style = "## Host setup\n\nStyles live in ...";};
      description = "Host-specific Markdown appended to a skill's SKILL.md at build time.";
    };
    showboatPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "showboat package for build-a-demo. The skill is not installed when null.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.all (n: builtins.elem n allSkills) (lib.attrNames cfg.extraSections);
          message = "dotfiles.skills.extraSections names a skill that doesn't exist.";
        }
      ];
      home.file = lib.listToAttrs (map (n:
        lib.nameValuePair ".claude/skills/${n}/SKILL.md" {text = skillText n;})
      enabled);
    }

    (lib.mkIf (has "build-a-demo") {
      home.packages = [cfg.showboatPackage pkgs.mermaid-cli];
      ai.permissions.claudeCode.allowedTools = ["Bash(showboat *)" "Bash(mmdc *)"];
      ai.permissions.openCode.bash = {
        "showboat *" = "allow";
        "mmdc *" = "allow";
      };
    })

    (lib.mkIf (has "in-browser") {
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux (import ./in-browser/packages.nix {inherit pkgs;});
      ai.permissions.claudeCode.allowedTools = [
        "Bash(rodney *)"
        "Bash(terminal-browser *)"
        "Bash(browser-close *)"
        "Bash(herdr-compat pane *)"
      ];
      ai.permissions.openCode.bash = {
        "rodney *" = "allow";
        "terminal-browser *" = "allow";
        "browser-close *" = "allow";
        "herdr-compat pane *" = "allow";
      };
    })

    (lib.mkIf (has "output-style") {
      ai.permissions.claudeCode.allowedTools = ["Bash(find *)" "AskUserQuestion"];
    })

    (lib.mkIf (has "tuicr-review") {
      ai.permissions.claudeCode.allowedTools = [
        "Bash(tuicr-wrapper *)"
        "Bash(tuicr review *)"
        "Bash(git init *)"
        "Bash(git add *)"
        "Bash(git commit *)"
        "Bash(git config *)"
        "Bash(mkdir /tmp/tuicr-review-*)"
        "Bash(cat *)"
        "Bash(pgrep -x tuicr)"
        "CronCreate"
      ];
      ai.permissions.claudeCode.excludedCommands = ["tuicr-wrapper"];
      ai.permissions.openCode.bash = {
        "tuicr-wrapper *" = "allow";
        "tuicr review *" = "allow";
        "git init *" = "allow";
        "git add *" = "allow";
        "git commit *" = "allow";
        "git config *" = "allow";
        "pgrep -x tuicr" = "allow";
        "sleep *" = "allow";
      };
    })
  ]);
}
