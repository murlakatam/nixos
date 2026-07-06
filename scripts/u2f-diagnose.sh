#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# u2f-diagnose.sh — find out exactly WHY pam_u2f rejects a YubiKey touch.
#
# It installs a throwaway debug PAM service, runs the real pam_u2f auth stack
# with the `debug` flag against a fresh enrollment, prints the exact failure
# reason, then cleans up. Needs sudo (to write /etc/pam.d) and a physical touch.
#
#   sudo ./u2f-diagnose.sh        # (it re-invokes sudo itself where needed)
#   ./u2f-diagnose.sh             # will prompt for sudo when required
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

USER_NAME="${SUDO_USER:-$USER}"
ORIGIN="pam://$(hostname)"
MAPPING="/tmp/u2f_diag_mapping"
SVC_NAME="u2fdbg"
SVC_FILE="/etc/pam.d/${SVC_NAME}"

PAM_U2F="$(ls /nix/store/*pam_u2f*/lib/security/pam_u2f.so 2>/dev/null | head -1)"
PAM_PERMIT="$(ls /nix/store/*linux-pam*/lib/security/pam_permit.so 2>/dev/null | head -1)"
PAMTESTER="/tmp/pamtester-link/bin/pamtester"

say() { printf '\n=== %s ===\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -n "$PAM_U2F" ]   || die "pam_u2f.so not found in /nix/store"
[ -n "$PAM_PERMIT" ] || die "pam_permit.so not found in /nix/store"

# Get pamtester if the earlier build link is gone.
if [ ! -x "$PAMTESTER" ]; then
  say "Fetching pamtester"
  nix build 'nixpkgs#pamtester' -o /tmp/pamtester-link || die "could not build pamtester"
fi

say "Environment"
echo "user:    $USER_NAME"
echo "origin:  $ORIGIN"
echo "pam_u2f: $PAM_U2F"
echo "pcscd:   $(systemctl is-active pcscd 2>/dev/null) (this is the prime suspect)"

# 1) Fresh enrollment (presence-only). TOUCH when it flashes.
say "Enrolling a fresh credential — TOUCH THE KEY WHEN IT FLASHES"
if ! pamu2fcfg -o "$ORIGIN" -i "$ORIGIN" -u "$USER_NAME" > "$MAPPING" 2>/tmp/u2f_diag_enroll_err; then
  cat /tmp/u2f_diag_enroll_err >&2
  die "enrollment failed"
fi
echo "enrolled mapping: $(cut -c1-40 "$MAPPING")..."
echo "cred fields: $(awk -F: '{print (split($2,a,","))}' "$MAPPING")  options: $(awk -F: '{split($2,a,","); print a[4]}' "$MAPPING")"

# 2) Install a debug PAM service with the same params the real service uses.
say "Installing debug PAM service ($SVC_FILE)"
sudo tee "$SVC_FILE" >/dev/null <<PAMEOF
auth required $PAM_U2F authfile=$MAPPING origin=$ORIGIN appid=$ORIGIN cue debug userpresence=1
account required $PAM_PERMIT
PAMEOF

# 3) Run the real pam_u2f stack with debug. TOUCH when it flashes.
say "Running pam_u2f (debug) — TOUCH THE KEY WHEN IT FLASHES"
echo "--- pam_u2f debug output below (this is the answer) ---"
"$PAMTESTER" -v "$SVC_NAME" "$USER_NAME" authenticate 2>&1
RESULT=$?
echo "--- pamtester exit=$RESULT (0 = SUCCESS, key works; non-zero = failed) ---"

# 4) Cleanup.
say "Cleanup"
sudo rm -f "$SVC_FILE"
rm -f "$MAPPING" /tmp/u2f_diag_enroll_err
echo "done."

if [ "$RESULT" -eq 0 ]; then
  echo
  echo ">>> SUCCESS: the key authenticates. If the real nixos-rebuild-ai still"
  echo ">>> fails, the installed /etc/u2f_mappings is stale — re-enroll & install."
else
  echo
  echo ">>> FAILED: read the debug lines above. Look for phrases like:"
  echo ">>>   'unable to open' / 'pcsc'   -> transport conflict (pcscd/libfido2)"
  echo ">>>   'device not found'          -> authfile/user mapping mismatch"
  echo ">>>   'signature verification'    -> credential/COSE mismatch"
  echo ">>>   'not a known origin'         -> origin/appid mismatch"
fi
