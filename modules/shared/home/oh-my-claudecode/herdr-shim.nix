# Inside herdr, runs `omc team|ralph|ultrawork` in a visible tab and mirrors its output.
# Every other command goes straight to the real omc.
{
  package,
  pkgs,
}:
pkgs.writeShellScriptBin "omc" ''
  set -euo pipefail

  REAL_OMC="${package}/bin/omc"
  TIMEOUT_MS="''${HERDR_OMC_TIMEOUT_MS:-1800000}"

  # TUI: HERDR_ENV=1 plus its socket. Herdr app: HC_TERMINAL_ID, no HERDR_ENV.
  if [ $# -eq 0 ]; then
    exec "$REAL_OMC" "$@"
  elif [ "''${HERDR_ENV:-}" = "1" ] && [ -n "''${HERDR_SOCKET_PATH:-}" ]; then
    BACKEND=tui
  elif [ "''${HERDR_ENV:-}" != "1" ] && [ -n "''${HC_TERMINAL_ID:-}" ]; then
    BACKEND=app
  else
    exec "$REAL_OMC" "$@"
  fi

  case "$1" in
    team|ralph|ultrawork) ;;
    *) exec "$REAL_OMC" "$@" ;;
  esac

  subcmd="$1"
  cmd="$REAL_OMC"
  for arg in "$@"; do
    cmd="$cmd $(printf '%q' "$arg")"
  done

  sentinel="__OMC_HERDR_DONE_$(date +%s%N)_$$__"
  wrapped="$cmd; __rc=\$?; printf '%s_RC_%d\n' '$sentinel' \"\$__rc\""

  if [ "$BACKEND" = app ]; then
    # Herdr app: a tab running the command through bash -c. It ends in the
    # user's shell so the tab stays for inspection, like the TUI's tab. hc
    # read polls for the sentinel (hc wait also ends on any message to us).
    app_cmd="$wrapped"'; exec "$SHELL"'
    opened="$(herdr-app do tab.new --name "omc-$subcmd" --folder "$PWD" \
      --argv "$(${pkgs.jq}/bin/jq -cn --arg c "$app_cmd" '["bash","-c",$c]')")"
    term="$(printf '%s' "$opened" | ${pkgs.jq}/bin/jq -r '.terminal // empty')"
    if [ -z "$term" ]; then
      echo "omc-herdr: could not open a Herdr tab: $opened" >&2
      exit 1
    fi
    end=$((SECONDS + TIMEOUT_MS / 1000))
    until hc read "$term" --lines 50 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q -F "''${sentinel}_RC_"; do
      if [ "$SECONDS" -ge "$end" ]; then
        echo "omc-herdr: timed out after ''${TIMEOUT_MS}ms waiting for completion in terminal $term" >&2
        echo "omc-herdr: switch to the omc-$subcmd tab to see live status" >&2
        exit 124
      fi
      sleep 0.5
    done
    # Stop at the sentinel: the tab's shell prompt follows it.
    hc read "$term" --lines 5000 | ${pkgs.gawk}/bin/awk -v s="$sentinel" 'index($0, s) { exit } { print }'
    rc="$(hc read "$term" --lines 50 \
      | ${pkgs.gnugrep}/bin/grep -F "$sentinel" \
      | tail -n1 \
      | ${pkgs.gnused}/bin/sed -E "s/.*''${sentinel}_RC_([0-9]+).*/\1/")"
    exit "''${rc:-0}"
  fi

  tab_json="$(herdr tab create --cwd "$PWD" --label "omc-$subcmd" --focus)"
  pane_id="$(printf '%s' "$tab_json" | ${pkgs.python3}/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["id"])')"

  herdr pane run "$pane_id" "$wrapped"

  if ! herdr wait output "$pane_id" --match "$sentinel" --timeout "$TIMEOUT_MS" >/dev/null; then
    echo "omc-herdr: timed out after ''${TIMEOUT_MS}ms waiting for completion in pane $pane_id" >&2
    echo "omc-herdr: switch to the omc-$subcmd tab to see live status" >&2
    exit 124
  fi

  herdr pane read "$pane_id" --source recent --lines 5000 \
    | ${pkgs.gnugrep}/bin/grep -v -F "$sentinel" || true

  rc="$(herdr pane read "$pane_id" --source recent --lines 50 \
    | ${pkgs.gnugrep}/bin/grep -F "$sentinel" \
    | tail -n1 \
    | ${pkgs.gnused}/bin/sed -E "s/.*''${sentinel}_RC_([0-9]+).*/\1/")"
  exit "''${rc:-0}"
''
