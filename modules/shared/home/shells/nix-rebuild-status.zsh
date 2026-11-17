# Report who holds the nix rebuild lock, without keeping it.
#
# The lock is taken by nix-rebuild, nix-update-flake and nix-update-ai (see
# nix-rebuild-lock.zsh). Exit 0 when it is free, 75 (EX_TEMPFAIL, "try again
# later") when someone holds it. With -q it prints nothing, only the exit code,
# so a caller can wait:
#
#   until nix-rebuild-status -q; do sleep 15; done
#
# This is zsh on purpose. The holder locks with zsystem flock, which is an
# fcntl lock; flock(1) takes a different kind (flock(2)) that does not conflict
# with it, so a bash version of this probe would report "free" while the lock
# is held. NIX_REBUILD_LOCK overrides the lock path (the tests use it).

zmodload zsh/system zsh/datetime

quiet=0
[[ "$1" == "-q" ]] && quiet=1

lock=${NIX_REBUILD_LOCK:-${XDG_RUNTIME_DIR:-/run/user/$UID}/nix-rebuild.lock}
info=$lock.info

# zsystem flock does not create the file, and a missing file fails with the same
# status as a held lock, so create it first and tell the two apart.
if ! { [[ -e "$lock" ]] || : >> "$lock"; } 2>/dev/null; then
    print -u2 -- "Cannot create the nix rebuild lock file $lock"
    exit 2
fi

# Probe with a lock of our own; it is released when this process exits.
if zsystem flock -t 0 -f fd "$lock" 2>/dev/null; then
    (( quiet )) || print -r -- "free"
    exit 0
fi

(( quiet )) && exit 75

typeset -A h
if [[ -r "$info" ]]; then
    while IFS== read -r k v; do
        h[$k]=$v
    done < "$info"
fi

duration() {
    if (( $1 >= 3600 )); then
        printf '%dh%02dm' $(( $1 / 3600 )) $(( $1 % 3600 / 60 ))
    else
        printf '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 ))
    fi
}

print -r -- "⛔ A nix rebuild is already running. Wait for it to finish, then retry."

if [[ -z "${h[pid]}" ]]; then
    print -r -- "   Holder:   unknown (the lock is held but has no holder info)"
else
    state="pid ${h[pid]}"
    if [[ "${h[started]}" == <-> ]]; then
        state="$state, running $(duration $(( EPOCHSECONDS - h[started] )))"
    fi
    if ! kill -0 "${h[pid]}" 2>/dev/null; then
        state="$state, process gone; a child of it may still hold the lock"
    fi
    print -r -- "   Holder:   ${h[label]:-nix rebuild} ($state)"
    [[ -n "${h[detail]}" ]] && print -r -- "   Command:  ${h[detail]}"
    [[ -n "${h[cwd]}" ]] && print -r -- "   Started:  in ${h[cwd]}"
    [[ -n "${h[chain]}" ]] && print -r -- "   Caller:   ${h[chain]}"
    [[ -n "${h[pane]}" ]] && print -r -- "   Herdr:    pane ${h[pane]}"
fi

print -r -- "   Lock:     $lock"
print -r -- "   Wait:     until nix-rebuild-status -q; do sleep 15; done"
exit 75
