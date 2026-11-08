# Global Claude Code skills (~/.claude/skills/*), generated from installed tools.
{
  pkgs,
  inputs,
  ...
}: let
  herdr = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  # `herdr --skill` prints the SKILL.md matching the installed herdr version.
  herdrSkill = pkgs.runCommand "herdr-claude-skill" {} ''
    HOME=$TMPDIR ${herdr}/bin/herdr --skill > $out
  '';
in {
  home.file.".claude/skills/herdr/SKILL.md".source = herdrSkill;
}
