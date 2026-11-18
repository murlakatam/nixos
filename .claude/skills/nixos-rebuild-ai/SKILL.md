---
name: nixos-rebuild-ai
description: Apply/rebuild/switch this NixOS + home-manager config. Use WHENEVER changes in this repo need to be applied ("rebuild", "switch", "make system", "nixos-rebuild", "apply the config", installing a package, testing a module). This is the ONLY approved rebuild path for Claude; it is token-efficient (one line on success).
allowed-tools: Bash(nixos-rebuild-ai:*)
---

# nixos-rebuild-ai — how Claude rebuilds this machine

Wrapper source: `scripts/nixos-rebuild-ai.zsh` (scoped-commit helpers
`_nix_scope_*` live in `modules/shared/home/shells/nix-rebuild-lock.zsh`). It
stages the paths you name, formats them with alejandra, runs
`nixos-rebuild switch --flake .#proartp16` via `sudo nixos-rebuild-ai-root`,
then on success commits **only those paths** (`git commit -- <paths>`; the body
lists the files). Success prints `OK: rebuilt + committed "<subject>"`, plus
warning lines if any. Failure dumps the full log to stderr and exits non-zero.

## The exact invocation

`nixos-rebuild-ai` is an executable on PATH (packaged in
`modules/homeManagerModules/custom-scripts.nix`), so call it directly:

```bash
nixos-rebuild-ai "<commit message>" <path>...
```

**Always pass every path you changed** (files or dirs, relative to your cwd or
absolute; new and deleted files included, an optional `--` before them is fine).
Other agents edit this repo concurrently; naming paths keeps their edits out of
your commit. Without paths it falls back to committing every tracked change and
warns `no paths given: committed every tracked change ...`.

The build itself always includes every uncommitted change in the tree (flakes
read the work tree). With paths, tracked changes outside them are listed as
`also in this build, NOT committed: ...`. That's informational: they're someone
else's WIP. Mention them to the user if they could affect your result.

Use `timeout: 600000`. If you expect a long local build (see pre-flight), use
`run_in_background: true` and wait for the completion notification instead of
polling.

## Pre-flight (cheap, no root)

1. **Name your paths** (see above); the wrapper `git add`s them, so new files
   are tracked for the flake. A typo'd path fails before building (exit 2).
2. **Check the tree.** Run `git status --short`; changes you didn't make are
   someone else's: leave them alone (don't name them, don't commit them).
3. **Evaluate first** to catch eval errors and see what will compile:
   ```bash
   nix build --dry-run .#nixosConfigurations.proartp16.config.system.build.toplevel 2>&1 | grep -E 'error|will be built' -A15 | head -40
   ```
   A big "will be built" list means a long switch: prebuild the new packages
   (`nix build --no-link ...`) so build failures surface before the switch.

## Commit message

Required (the wrapper exits 2 without one). Conventional style:
`feat(pkgs): add herdr tui + gui`. Multi-line works via `$'...'`, so include the
Co-Authored-By trailer this way when one is required:
`nixos-rebuild-ai $'feat: x\n\nCo-Authored-By: ...'`.

## Reading the result

- `OK: ...` → done. Read any `⚠️` lines above it. Don't re-run or "verify" with another rebuild.
- `FAILED (exit N)` with a nix error → fix the config and re-run with a fresh
  message (nothing was committed). To save tokens, focus on the first `error:`
  and its trace; don't echo the whole log back to the user.
- Exit **75** with "A nix rebuild is already running" → another agent holds the
  per-host rebuild lock. Nothing was built or committed. Wait, then re-run:
  `until nix-rebuild-status -q; do sleep 15; done` (`nix-rebuild-status` alone
  prints `free` or who holds it).
- `sudo: a password is required` → the NOPASSWD rule for
  `nixos-rebuild-ai-root` (`modules/nixosModules/yubikey.nix`) isn't active on
  the running system. Don't retry or look for another way to get root. Stop and
  give the user the exact command to run in their own terminal.
- `build OK but commit FAILED` → the system IS switched; only git failed. Fix git
  by hand. Don't rebuild again.

## Hard rules

- NEVER use `nixos-rebuild`, `sudo nixos-rebuild`, `make system`, `make update`,
  `make`, the `rebuild` function, or `home-manager switch`. They open editors,
  prompt for passwords, push, and stream huge logs.
- `nix build`, `nix eval`, `nix flake ...` (no root) are fine for checking things.
  Updating `flake.lock` (`nix flake update`) is a user decision: ask first.
