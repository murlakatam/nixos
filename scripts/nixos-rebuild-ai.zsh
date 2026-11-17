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
#   - One rebuild at a time: runs under the shared nix rebuild lock (_nix_locked,
#     sourced by the bin wrapper). If another rebuild holds it, exits 75 at once
#     and prints the holder (same report as `nix-rebuild-status`).
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

  _nix_locked nixos-rebuild-ai "$msg" _nixos_rebuild_ai_core "$msg"
}

_nixos_rebuild_ai_core() {
  local configDir="@dotfilesPath@"
  local msg="$1"

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
    # Root has no GitHub key: put the private herdr-nix input (and every other
    # locked input) in the store as this user, so root's eval never fetches.
    nix flake archive . >/dev/null || exit 1
    # Absolute path MUST match the sudoers Cmnd_Alias verbatim (see yubikey.nix).
    # -n: never prompt (rule is NOPASSWD); fail fast if it isn't active.
    sudo -n /run/current-system/sw/bin/nixos-rebuild-ai-root
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
