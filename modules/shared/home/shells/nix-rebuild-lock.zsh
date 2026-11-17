# One nix rebuild at a time, across every shell, agent and terminal on this
# machine. nix-rebuild, nix-update-flake and nix-update-ai all run inside
# _nix_locked. A second caller does not queue: it fails at once with exit 75
# (EX_TEMPFAIL, "try again later") and a message naming the holder
# (nix-rebuild-status prints it).
#
# The lock is flock(2) on $XDG_RUNTIME_DIR/nix-rebuild.lock, so the kernel drops
# it when the holder dies, however it dies. Next to it, <lock>.info records who
# holds it: the command, pid, start time, cwd, process chain and herdr pane.
# The info file is only a label. The lock is the authority, and nix-rebuild-status
# says so when the holder it names is gone.
#
# Re-entrant within one shell: nix-update-ai holds the lock and calls nix-rebuild,
# which must not fight its own caller. Only the outermost call takes and drops the
# lock. NIX_REBUILD_LOCK overrides the path (the tests use it).

zmodload zsh/system zsh/datetime 2>/dev/null

typeset -gi _nix_lock_depth=0
typeset -g _nix_lock_fd=""

_nix_lock_path() {
    print -r -- "${NIX_REBUILD_LOCK:-${XDG_RUNTIME_DIR:-/run/user/$UID}/nix-rebuild.lock}"
}

# Record who holds the lock. Best effort: a failure here never blocks the run.
_nix_lock_write_info() {
    local lock="$1" label="$2" detail="$3"
    local -a names
    local p=$$ i
    for i in {1..6}; do
        names+=("$(ps -o comm= -p "$p" 2>/dev/null)")
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        [[ -z "$p" || "$p" == 0 || "$p" == 1 ]] && break
    done
    {
        print -r -- "label=$label"
        print -r -- "pid=$$"
        print -r -- "started=$EPOCHSECONDS"
        print -r -- "cwd=$PWD"
        print -r -- "detail=${detail//$'\n'/ }"
        print -r -- "chain=${(j: ← :)names}"
        print -r -- "pane=${HERDR_PANE_ID:-}"
    } >| "$lock.info" 2>/dev/null
    return 0
}

_nix_lock_busy() {
    if command -v nix-rebuild-status >/dev/null 2>&1; then
        nix-rebuild-status >&2
    else
        print -u2 -- "⛔ A nix rebuild is already running. Wait for it to finish, then retry. (lock: $1)"
    fi
}

# _nix_lock_acquire <label> <detail>. Returns 0 when held (taken now, or already
# held by this shell), 75 when another process holds it.
_nix_lock_acquire() {
    local label="$1" detail="$2"
    if (( _nix_lock_depth > 0 )); then
        (( _nix_lock_depth++ ))
        return 0
    fi

    local lock fd attempt
    lock=$(_nix_lock_path)
    # zsystem flock does not create the file, and a missing file fails with the
    # same status as a held lock, so create it first and tell the two apart.
    if ! { [[ -e "$lock" ]] || : >> "$lock"; } 2>/dev/null; then
        print -u2 -- "⛔ Cannot create the nix rebuild lock file $lock"
        return 1
    fi
    for attempt in 1 2; do
        if zsystem flock -t 0 -f fd "$lock" 2>/dev/null; then
            _nix_lock_fd=$fd
            _nix_lock_depth=1
            _nix_lock_write_info "$lock" "$label" "$detail"
            return 0
        fi
        # nix-rebuild-status probes with a brief lock of its own. If it says the
        # lock is free, that was the probe and not a holder: try once more.
        if (( attempt == 1 )) && command -v nix-rebuild-status >/dev/null 2>&1 \
            && nix-rebuild-status -q; then
            continue
        fi
        break
    done

    _nix_lock_busy "$lock"
    return 75
}

_nix_lock_release() {
    (( _nix_lock_depth > 0 )) || return 0
    (( _nix_lock_depth-- ))
    (( _nix_lock_depth == 0 )) || return 0

    local lock
    lock=$(_nix_lock_path)
    # Remove the info file only if it is ours, and before unlocking, so a new
    # holder's file is never deleted.
    if [[ "$(sed -n 's/^pid=//p' "$lock.info" 2>/dev/null)" == "$$" ]]; then
        rm -f "$lock.info"
    fi
    zsystem flock -u "$_nix_lock_fd" 2>/dev/null
    _nix_lock_fd=""
    return 0
}

# _nix_locked <label> <detail> <function> [args...]: run the function holding the
# lock, release it however the function ends, then (outermost call only, lock
# already dropped) run _nix_rebuild_post. That is where the drift summary and the
# fix session live: a session that can last an hour must not hold up rebuilds.
_nix_locked() {
    local label="$1" detail="$2"
    shift 2
    _nix_lock_acquire "$label" "$detail" || return $?

    local rc=0
    {
        "$@"
        rc=$?
    } always {
        _nix_lock_release
    }

    if (( _nix_lock_depth == 0 )) && (( ${+functions[_nix_rebuild_post]} )); then
        _nix_rebuild_post
    fi
    return $rc
}
