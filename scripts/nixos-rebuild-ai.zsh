# Token-efficient, non-interactive NixOS rebuild wrapper for AI agents.
#
# Contract:
#   - Takes a git commit message (required), then optionally the paths the caller
#     changed. With paths, only those are staged and committed; other sessions'
#     edits stay uncommitted (but are still IN the build: flakes read the work
#     tree, so they're listed on stderr). Without paths: old behaviour (commit
#     every tracked change) plus a warning naming what was committed.
#   - NEVER opens an editor, NEVER prompts for a password, NEVER blocks on stdin.
#   - Privilege escalation is gated by a YubiKey TOUCH (user presence), not a
#     password: the privileged step goes through `sudo nixos-rebuild-ai-root`
#     which is wired to a U2F-only PAM service. No touch => it fails closed.
#   - On SUCCESS: prints one terse line (plus warnings, if any). No diff, no logs.
#   - On FAILURE: prints the FULL captured output, then exits non-zero.
#   - Commit happens UNPRIVILEGED (as you), only after a successful build.
#   - One rebuild at a time: runs under the shared nix rebuild lock (_nix_locked,
#     sourced by the bin wrapper together with the _nix_scope_* helpers). If
#     another rebuild holds it, exits 75 at once and prints the holder.
#
# Usage:
#   nixos-rebuild-ai "feat: add foo module" [--] [path...]
nixos-rebuild-ai() {
  local msg="$1"

  if [[ -z "$msg" ]]; then
    print -ru2 -- "ERROR: commit message required. Usage: nixos-rebuild-ai \"<commit message>\" [path...]"
    return 2
  fi
  shift
  # absolute paths, resolved against the caller's cwd
  local -a reply
  _nix_scope_args "$@"

  _nix_locked nixos-rebuild-ai "$msg" _nixos_rebuild_ai_core "$msg" "${reply[@]}"
}

_nixos_rebuild_ai_core() {
  local configDir="@dotfilesPath@"
  local msg="$1"
  shift
  local -a paths=("$@")

  # NB: do NOT name this `status` — that's a read-only special var in zsh.
  local log rc foreign
  log="$(mktemp -t nixos-rebuild-ai.XXXXXX)"

  # ── Stage the caller's paths (new files must be tracked for the flake) ──
  if (( ${#paths} )); then
    if ! (cd "$configDir" && _nix_scope_stage "${paths[@]}") >"$log" 2>&1; then
      print -ru2 -- "nixos-rebuild-ai: could not stage the given paths (nothing built):"
      cat -- "$log" >&2
      rm -f -- "$log"
      return 2
    fi
  fi

  # ── Privileged build (touch-gated) ──────────────────────────────────────
  # `sudo nixos-rebuild-ai-root` triggers a YubiKey touch prompt via PAM.
  # The helper takes no arguments and does the switch as root. All output is
  # captured; nothing streams to the caller unless it fails.
  (
    cd "$configDir" || exit 1
    if (( ${#paths} )); then
      alejandra -- "${paths[@]}" >/dev/null 2>&1 # format only the caller's files
      _nix_scope_stage "${paths[@]}" || exit 1 # pick up formatter changes
    else
      alejandra . >/dev/null 2>&1 # format (best-effort; noise suppressed)
    fi
    # Root has no GitHub key: put the private herdr-nix input (and every other
    # locked input) in the store as this user, so root's eval never fetches.
    nix flake archive . >/dev/null || exit 1
    # Absolute path MUST match the sudoers Cmnd_Alias verbatim (see yubikey.nix).
    # -n: never prompt (rule is NOPASSWD); fail fast if it isn't active.
    sudo -n /run/current-system/sw/bin/nixos-rebuild-ai-root
  ) >>"$log" 2>&1
  rc=$?

  if [[ $rc -ne 0 ]]; then
    print -ru2 -- "nixos-rebuild-ai FAILED (exit $rc):"
    cat -- "$log" >&2
    rm -f -- "$log"
    return $rc
  fi

  # ── Unprivileged commit (as you), only on a successful build ────────────
  if (( ${#paths} )); then
    foreign=$(cd "$configDir" && _nix_scope_foreign "${paths[@]}")
  fi
  (
    cd "$configDir" || exit 1
    _nix_scope_commit "$msg" "${paths[@]}"
  ) >>"$log" 2>"$log.warn"
  rc=$?

  if [[ $rc -ne 0 ]]; then
    print -ru2 -- "nixos-rebuild-ai: build OK but commit FAILED (exit $rc):"
    cat -- "$log" "$log.warn" >&2
    rm -f -- "$log" "$log.warn"
    return $rc
  fi

  cat -- "$log.warn" >&2
  if [[ -n "$foreign" ]]; then
    print -ru2 -- "⚠️  also in this build, NOT committed (other sessions' WIP?): ${(j:, :)${(f)foreign}}"
  fi
  rm -f -- "$log" "$log.warn"
  print -r -- "OK: rebuilt + committed \"${msg%%$'\n'*}\""
  return 0
}
