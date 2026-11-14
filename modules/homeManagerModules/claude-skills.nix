# Global Claude Code skills (~/.claude/skills/*).
# - vendored skills: ./claude-skills/<name>/ (one dir per skill)
# - upstream skills: pinned fetches
# - generated skills: built from installed tools
# ~/.claude/skills/synced is claude.ai's own sync and is deliberately not managed.
{
  pkgs,
  lib,
  ...
}: let
  # herdr skills (herdr, herdr-subagent, herd-new, ...) come from the private
  # herdr-nix flake input, imported in hosts/proartp16/home.nix.
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
    ]
  );
}
