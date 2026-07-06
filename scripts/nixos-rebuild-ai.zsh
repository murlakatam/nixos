# Token-efficient, non-interactive NixOS rebuild wrapper for AI agents.
#
# Contract:
#   - Takes a git commit message as its single argument (required).
#   - NEVER opens an editor, NEVER prompts, NEVER blocks on input.
#   - On SUCCESS: prints one terse line. No diff, no logs, no notifications.
#   - On FAILURE: prints the FULL captured build/commit output, then exits non-zero.
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

  local host flake log status
  host="$(hostname)"
  flake=".#${host}"
  log="$(mktemp -t nixos-rebuild-ai.XXXXXX)"

  # Run everything from the config dir without disturbing the caller's cwd.
  (
    cd "$configDir" || exit 1

    # Format (non-fatal noise suppressed; only surfaces on hard failure below).
    alejandra . >/dev/null 2>&1

    # Build + switch. All output captured; nothing streamed to the caller.
    sudo nixos-rebuild switch --flake "$flake" --show-trace || exit 1

    # Commit with the provided message. Nothing to commit is not an error.
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git commit -am "$msg" || exit 1
    fi
  ) >"$log" 2>&1
  status=$?

  if [[ $status -ne 0 ]]; then
    print -ru2 -- "nixos-rebuild-ai FAILED (exit $status):"
    cat -- "$log" >&2
    rm -f -- "$log"
    return $status
  fi

  rm -f -- "$log"
  print -r -- "OK: rebuilt + committed \"$msg\""
  return 0
}
