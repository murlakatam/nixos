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
#
# Also here: the scoped-commit helpers (_nix_scope_*, at the end) that rebuild
# commands use to commit only their caller's paths.

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

# ── Scoped commits ─────────────────────────────────────────────────────────────
# Rebuild commands that commit take the paths their caller changed, so a rebuild
# commits only those and never another agent's edits. Run these inside the repo.
# The BUILD still reads the whole work tree (flakes do), so _nix_scope_foreign
# lists what the build includes but the commit leaves out.
#
#   _nix_scope_args <args...>      sets reply=(absolute paths), dropping a leading --
#   _nix_scope_stage <paths...>    git add -A them (new/deleted files too); fails on a typo
#   _nix_scope_foreign <paths...>  tracked changes outside the paths, one per line
#   _nix_scope_commit <msg> [paths...]
#       with paths: commit only them (git commit -- paths), body lists the files;
#       without:   commit every tracked change (old behaviour), body lists the files,
#                  and print a warning naming them on stderr.

_nix_scope_args() {
    [[ "${1:-}" == "--" ]] && shift
    reply=()
    local p
    for p in "$@"; do reply+=("${p:a}"); done
}

_nix_scope_stage() {
    (( $# )) || return 0
    # git add rejects a path whose deletion is already staged (it is in neither
    # the work tree nor the index), so skip those. A typo has no staged deletion
    # and still reaches git add, which fails on it.
    local p
    local -a todo
    for p in "$@"; do
        if [[ ! -e "$p" && ! -L "$p" && -z "$(git ls-files -- "$p")" \
            && -n "$(git diff --cached --name-only --diff-filter=D -- "$p")" ]]; then
            continue
        fi
        todo+=("$p")
    done
    (( ${#todo} )) || return 0
    git add -A -- "${todo[@]}"
}

# Repo-relative form of each path (absolute or relative to $PWD).
_nix_scope_rel() {
    local top p
    top=$(git rev-parse --show-toplevel) || return 1
    for p in "$@"; do
        p=${p:a}
        p=${p#$top}
        p=${p#/}
        print -r -- "${p%/}"
    done
}

_nix_scope_foreign() {
    local -a mine
    mine=("${(@f)$(_nix_scope_rel "$@")}")
    local line f p hit
    git status --porcelain=v1 --untracked-files=no | while IFS= read -r line; do
        f=${line:3}
        f=${f##* -> }
        hit=0
        for p in "${mine[@]}"; do
            if [[ -z "$p" || "$f" == "$p" || "$f" == "$p"/* ]]; then
                hit=1
                break
            fi
        done
        (( hit )) || print -r -- "$f"
    done
}

_nix_scope_commit() {
    local msg="$1"
    shift
    local files
    if (( $# )); then
        files=$(git diff --cached --name-only -- "$@")
        if [[ -z "$files" ]]; then
            print -r -- "nothing to commit in the named paths"
            return 0
        fi
        git commit -q -m "$msg" -m "Files:"$'\n'"$files" -- "$@"
    else
        files=$( { git diff --cached --name-only; git diff --name-only; } | sort -u)
        if [[ -z "$files" ]]; then
            print -r -- "nothing to commit"
            return 0
        fi
        git commit -q -am "$msg" -m "Files:"$'\n'"$files" || return $?
        print -ru2 -- "⚠️  no paths given: committed every tracked change, maybe other sessions' too: ${(j:, :)${(f)files}}"
    fi
}
