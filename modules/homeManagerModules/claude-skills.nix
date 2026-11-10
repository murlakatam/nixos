# Global Claude Code skills (~/.claude/skills/*).
# - vendored skills: ./claude-skills/<name>/ (one dir per skill)
# - upstream skills: pinned fetches
# - generated skills: built from installed tools
# ~/.claude/skills/synced is claude.ai's own sync and is deliberately not managed.
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  herdr = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  # `herdr --skill` prints the SKILL.md matching the installed herdr version.
  herdrSkill = pkgs.runCommand "herdr-claude-skill" {} ''
    HOME=$TMPDIR ${herdr}/bin/herdr --skill > $out
  '';

  terraformSkill = pkgs.fetchFromGitHub {
    owner = "antonbabenko";
    repo = "terraform-skill";
    rev = "a4503cb02fa035e85b5585b96cbbf34bad977309";
    hash = "sha256-aO6gypRfvsGSnvgygxIHaTagT4bgR6FNUiVWVXtVbD8=";
  };

  vendoredDir = ./claude-skills;
  vendored = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir vendoredDir));

  skillDir = name: src: {
    ".claude/skills/${name}" = {
      source = src;
      recursive = true;
    };
  };
in {
  home.file = lib.mkMerge (
    (map (name: skillDir name (vendoredDir + "/${name}")) vendored)
    ++ [
      (skillDir "terraform-skill" terraformSkill)
      {".claude/skills/herdr/SKILL.md".source = herdrSkill;}
    ]
  );
}
