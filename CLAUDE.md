# NixOS dotfiles (host: proartp16)

Flake-based NixOS + home-manager config. System modules live in
`modules/nixosModules/`, home-manager modules in `modules/homeManagerModules/`,
and the host entry points in `hosts/proartp16/`.

## Applying changes

ALWAYS use the `nixos-rebuild-ai` skill (`.claude/skills/nixos-rebuild-ai/SKILL.md`)
to rebuild/switch. Load it before the first rebuild in a session. Short version:
`nixos-rebuild-ai "<commit message>"` (it formats, switches and commits; one
`OK:` line on success). Never use `nixos-rebuild`, `make system` or `rebuild`
directly.
