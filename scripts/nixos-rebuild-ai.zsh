# Token-efficient, non-interactive NixOS rebuild wrapper for AI agents.
#
# Contract:
#   - Takes a git commit message as its single argument (required).
#   - NEVER opens an editor, NEVER prompts for a password, NEVER blocks on stdin.
#   - Privilege escalation is gated by a YubiKey TOUCH (user presence), not a
#     password: the privileged step goes through `sudo nixos-rebuild-ai-root`
#     which is wired to a U2F-only PAM service. No touch => it fails closed.
#   - On SUCCESS: prints one terse line. No diff, no logs, no notifications.
#   - On FAILURE: prints the FULL captured output, then exits non-zero.
#   - Commit happens UNPRIVILEGED (as you), only after a successful build.
#
# Usage:
#   nixos-rebuild-ai "feat: add foo module"
nixos-rebuild-ai() {
  local configDir="@dotfilesPath@"
  local msg="$1"

  if [[ -z "$msg" ]]; then
    print -ru2 -- "ERROR: commit message required. Usage: nixos-rebuild-ai \"<commit message>\""
    return 2
  fi

  # NB: do NOT name this `status` — that's a read-only special var in zsh.
  local log rc
  log="$(mktemp -t nixos-rebuild-ai.XXXXXX)"

  # ── Privileged build (touch-gated) ──────────────────────────────────────
  # `sudo nixos-rebuild-ai-root` triggers a YubiKey touch prompt via PAM.
  # The helper takes no arguments and does the switch as root. All output is
  # captured; nothing streams to the caller unless it fails.
  (
    cd "$configDir" || exit 1
    alejandra . >/dev/null 2>&1 # format (best-effort; noise suppressed)
    # Absolute path MUST match the sudoers Cmnd_Alias verbatim (see yubikey.nix).
    sudo /run/current-system/sw/bin/nixos-rebuild-ai-root
  ) >"$log" 2>&1
  rc=$?

  if [[ $rc -ne 0 ]]; then
    print -ru2 -- "nixos-rebuild-ai FAILED (exit $rc):"
    cat -- "$log" >&2
    rm -f -- "$log"
    return $rc
  fi

  # ── Unprivileged commit (as you), only on a successful build ────────────
  (
    cd "$configDir" || exit 1
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git commit -am "$msg"
    fi
  ) >>"$log" 2>&1
  rc=$?

  if [[ $rc -ne 0 ]]; then
    print -ru2 -- "nixos-rebuild-ai: build OK but commit FAILED (exit $rc):"
    cat -- "$log" >&2
    rm -f -- "$log"
    return $rc
  fi

  rm -f -- "$log"
  print -r -- "OK: rebuilt + committed \"$msg\""
  return 0
}
