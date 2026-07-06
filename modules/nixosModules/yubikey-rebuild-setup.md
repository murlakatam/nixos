# Touch-gated `nixos-rebuild-ai` — setup & mental model

This machine's rebuild path is gated by a **YubiKey touch** instead of a
password. Both the manual flow (`rebuild` / `make system`) and the AI wrapper
(`nixos-rebuild-ai "<msg>"`) escalate through the same helper and require a
physical tap. General `sudo` is unaffected (still password-protected).

## How it works (why not just NOPASSWD)

`NOPASSWD` turns sudo authentication OFF entirely, which bypasses the whole PAM
auth stack — so it could never demand a touch. Instead we keep sudo auth ON
(`PASSWD`) and, for one command only, redirect it to a dedicated PAM service
whose auth stack is U2F-only:

```
auth required pam_u2f.so ... cue userpresence=1   ← touch required
auth required pam_deny.so                          ← nothing else satisfies it
```

No `pam_unix` in that stack ⇒ no password. `pam_u2f required` + `pam_deny` ⇒
**fails closed**: no touch, wrong key, missing mapping, or dead `pcscd` ⇒ the
rebuild is refused (it errors out, it does not hang forever).

Pieces (all in `yubikey.nix`):
- `nixos-rebuild-ai-root` — root-only helper, **no args**, does the `switch`.
- `security.pam.services.nixos-rebuild-ai` — U2F-only PAM service.
- `security.sudo.extraConfig` — scoped rule: `PASSWD` + `pam_service=...` +
  `timestamp_timeout=0` (forces a fresh touch every time), matched on the stable
  `/run/current-system/sw/bin/nixos-rebuild-ai-root` path.
- User wrapper `nixos-rebuild-ai` (see `scripts/nixos-rebuild-ai.zsh`) does the
  `git commit` afterwards **as you** (commit is never a privileged step).

## One-time enrollment (REQUIRED before this works)

The PAM service reads key mappings from `/etc/u2f_mappings`. Until that file
exists and contains your key, the rebuild path will **fail closed**.

1. Plug in the YubiKey. `pamu2fcfg` is already installed system-wide (it ships
   with this module), so just run it directly. Generate a mapping (origin/appid
   MUST match the config, which pins them to `pam://proartp16`):

   ```bash
   pamu2fcfg -u eugene -o pam://proartp16 -i pam://proartp16 > /tmp/u2f_mappings
   # touch the key when it flashes

   # (optional) enroll a BACKUP key on the same line:
   pamu2fcfg -n -o pam://proartp16 -i pam://proartp16 >> /tmp/u2f_mappings
   ```

   > Note: don't use `nix shell nixpkgs#pam_u2f` in zsh — the `#` is a glob
   > character (extendedglob is on) and zsh will error with `no matches found`.
   > `pamu2fcfg` is already on your PATH, so you don't need it. If you ever do
   > need a `nix` flake ref in zsh, quote it: `nix shell 'nixpkgs#pkg'`.

2. Install it root-owned:

   ```bash
   sudo install -o root -g root -m 0644 /tmp/u2f_mappings /etc/u2f_mappings
   ```

3. Rebuild ONCE the classic way to activate the new PAM/sudo config
   (keep a root shell open in another terminal as a safety net):

   ```bash
   sudo nixos-rebuild switch --flake .#proartp16
   ```

4. Test it:

   ```bash
   nixos-rebuild-ai "test: touch-gated rebuild"
   # YubiKey should flash — tap it. Expect a single `OK:` line.
   ```

## Two paths, two behaviors

There are two rebuild helpers, each with its own PAM policy:

| Path | Command | Auth policy | If key absent |
|------|---------|-------------|---------------|
| **Agent** | `nixos-rebuild-ai "<msg>"` | **touch only** (`pam_u2f required`, no `pam_unix`) | **fails closed** — errors out, no password prompt |
| **Manual** | `make system` / `rebuild` | **touch OR password** (`pam_u2f sufficient`, then `pam_unix`) | prompts for your password |

- The **agent** path has NO password fallback, on purpose — that's the "fail if
  no real human touch" guarantee (a password alone must never authorize an
  unattended rebuild).
- The **manual** path DOES fall back to your password: tap the key normally, but
  if it's dead/absent you can still type your password. So your everyday
  `make system` never leaves you stuck.

Neither affects normal login or general `sudo` — those are unchanged and always
password-protected.

## Escape hatches (all work with NO YubiKey)

1. `make system` — the manual path already falls back to a password if no key.
2. `make system REPAIR=true` — classic password path (`sudo nixos-rebuild
   switch --repair`).
3. `sudo nixos-rebuild switch --flake .#proartp16` — plain sudo + password.
4. Boot a previous NixOS generation from the bootloader.

## Backup key — optional

Because the manual path falls back to a password and U2F is scoped to the
rebuild helpers only (not login/sudo), a lost key can NOT lock you out. A second
enrolled YubiKey is purely a convenience (keeps the tap-only agent path working
while you replace a lost key). To enroll one, use the `-n` line in step 1.

## Notes

- `timestamp_timeout=0` means every rebuild requires a fresh touch (a recent
  normal `sudo` won't silently authorize it).
- `/etc/u2f_mappings` is root-owned on purpose: a user-writable authfile would
  let the account swap which key is trusted without a privileged change.
