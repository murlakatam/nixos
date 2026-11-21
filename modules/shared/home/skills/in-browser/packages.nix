# Tools the in-browser skill drives.
{pkgs}: let
  rodney = pkgs.stdenv.mkDerivation rec {
    pname = "rodney";
    version = "0.4.0";
    src = pkgs.fetchurl {
      url = "https://github.com/simonw/rodney/releases/download/v${version}/rodney-linux-amd64.tar.gz";
      hash = "sha256-KU4mCqClcPSge77/GLzVw+VtIa1WH9EkFUpsUrkZmnU=";
    };
    sourceRoot = ".";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      cp rodney $out/bin/
      chmod +x $out/bin/rodney
    '';
  };
  # Close the visible-mode browser completely. `terminal-browser shutdown` only
  # stops the daemon and leaves the herdr pane behind; closing just the pane
  # leaves an idle daemon. ls --json reports each browser's herdr pane, so this
  # closes those panes, then stops the daemon once no browser is left.
  browserClose = pkgs.writeShellScriptBin "browser-close" ''
    set -euo pipefail
    usage() { echo "Usage: browser-close [--list] [--all]" >&2; exit 1; }
    all=0
    list=0
    for a in "$@"; do
      case "$a" in
        --all) all=1 ;;
        --list) list=1 ;;
        *) usage ;;
      esac
    done
    jq=${pkgs.jq}/bin/jq
    ls_json() { terminal-browser ls --all --json 2>/dev/null || echo '{"browsers":[]}'; }
    json=$(ls_json)
    # One "<herdr pane> <browser key>" line per browser pane. Default: only
    # browsers in the herdr tab this is run from; --all takes every one,
    # including other sessions' panes.
    if [ "$(herd-backend --strict)" = app ]; then
      # The app leaves ls's pane fields null, so match each app terminal's
      # tty to a browser's tty instead.
      label=()
      [ "$all" = 1 ] || label=(--label "herdr.tab=$(hc get "$HC_TERMINAL_ID" | $jq -r '.labels["herdr.tab"]')")
      pairs=""
      for t in $(hc ls --json "''${label[@]}" | $jq -r '.terminals[].address'); do
        pid=$(hc get "$t" | $jq -r '.pid // empty')
        [ -n "$pid" ] || continue
        tty=$(ps -o tty= -p "$pid" | tr -d ' ')
        key=$($jq -r --arg t "/dev/$tty" '.browsers[] | select(.tty == $t) | .key' <<<"$json")
        [ -n "$key" ] && pairs="$pairs$t $key"$'\n'
      done
    else
      pairs=$(terminal-browser ls --json 2>/dev/null | $jq -r --argjson all "$all" '.browsers[] | select($all == 1 or .inCurrentTab == true) | select(.pane.pane) | "\(.pane.pane) \(.key)"')
    fi
    if [ "$list" = 1 ]; then
      [ -n "$pairs" ] || { echo "no browser pane open"; exit 0; }
      while read -r pane key; do
        [ -n "$pane" ] || continue
        url=$($jq -r --arg k "$key" '.browsers[] | select(.key == $k) | (.tabs[] | select(.active) | .url) // "-"' <<<"$json")
        printf '%s  %b\n' "$pane" "''${url//%/\\x}"
      done <<<"$pairs"
      exit 0
    fi
    if [ -z "$pairs" ]; then
      echo "browser-close: no browser pane to close"
    else
      while read -r pane _; do
        [ -n "$pane" ] || continue
        herdr-compat pane close "$pane" >/dev/null
        echo "closed pane $pane"
      done <<<"$pairs"
    fi
    sleep 1
    if [ "$(ls_json | $jq '.browsers | length')" = 0 ]; then
      terminal-browser shutdown >/dev/null 2>&1 || true
      echo "no browsers left: stopped the idle daemon"
    fi
  '';
in [rodney browserClose]
