---
name: nixos-rebuild
description: Rebuild and switch this NixOS configuration. Use this skill WHENEVER you need to apply NixOS/home-manager changes, rebuild the system, "make system", "nixos-rebuild switch", or apply/deploy config changes on this machine. This is the ONLY approved way to rebuild.
allowed-tools: Bash(nixos-rebuild-ai:*)
---

# NixOS Rebuild (agent)

Apply NixOS/home-manager config changes on this machine.

## The ONLY command you may use

```
nixos-rebuild-ai "<git commit message>"
```

That's it. This wrapper is:

- **Non-interactive** — never opens an editor, never prompts for a password, never blocks on stdin.
- **Token-efficient** — prints nothing but a single `OK:` line on success.
- **Loud on failure** — dumps the full build log to stderr and exits non-zero.
- **Auto-committing** — formats with alejandra, does the privileged switch, then `git commit -am "<message>"` on success.

## IMPORTANT: requires a physical YubiKey touch

The privileged rebuild step is gated by a **YubiKey touch** (proof of human
presence) instead of a password. When you run `nixos-rebuild-ai`, a human must
physically tap the YubiKey when it flashes ("Please touch the device.").

- If nobody touches the key, the command **fails closed** — it does NOT hang
  forever, it errors out. This is expected and correct.
- You (the agent) **cannot** satisfy this yourself. If it fails with a U2F/PAM
  error, tell the user a touch is required and let them run it (or touch the key).
- Do **not** try to work around it with `sudo nixos-rebuild`, passwords, or any
  other escalation path — those are blocked / password-protected by design.

## Rules (HARD)

1. **NEVER** run `nixos-rebuild`, `sudo nixos-rebuild`, `make system`, `make update`,
   `make`, `home-manager switch`, the `rebuild` shell function, or any other rebuild
   path. Use `nixos-rebuild-ai` and nothing else.
2. **ALWAYS** pass a commit message. It is required; the command fails without one.
   Write a concise, conventional message describing the change
   (e.g. `feat: add foo module`, `fix: correct zsh alias`).
3. **Do NOT** wrap it in an editor, `--wait`, confirmation prompt, or pipe it through
   a pager. Call it directly.
4. On **success**: the command prints one `OK:` line — you're done. Do not re-run to
   "verify".
5. On **failure**: the full error log is on stderr. Read it, fix the config, then run
   `nixos-rebuild-ai` again with an appropriate message.

## Examples

Apply a change:

```
nixos-rebuild-ai "feat(shells): add nixos-rebuild-ai wrapper"
```

Retry after fixing a build error:

```
nixos-rebuild-ai "fix(module): correct option type"
```
