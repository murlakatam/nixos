# NixOS dotfiles (host: proartp16)

Flake-based NixOS + home-manager config. System modules live in
`modules/nixosModules/`, home-manager modules in `modules/homeManagerModules/`,
and the host entry points in `hosts/proartp16/`.

## Applying changes

ALWAYS use the `nixos-rebuild-ai` skill (`.claude/skills/nixos-rebuild-ai/SKILL.md`)
to rebuild/switch. Load it before the first rebuild in a session. Short version:
`nixos-rebuild-ai "<commit message>"` (it formats, switches and commits; one
`OK:` line on success). Never use `nixos-rebuild`, `make system` or `rebuild`
directly.

## Secrets: never print them (all agents, no exceptions)

Secrets have leaked into agent transcripts and logs more than once. Treat ALL of these as secret:
sops values, API keys, passwords, tokens, session cookies, auth headers, webhook secrets, and
any field of an *arr/Prowlarr/Vaultwarden/Plex config, database row or API response that could
hold one (download URLs with `apikey=`, indexer `fields`, `config.xml`, sqlite tables, cookie jars).

- **Print only counts, lengths or booleans.** `jq 'length'`, `wc -c`, `test -n`, HTTP status codes.
  Never print a value "truncated" or "masked" by hand: partial keys count as leaks, and ad-hoc
  masking filters miss multi-line JSON.
- **Send stdout to /dev/null when a command might echo a secret.** In zsh, `2>&1 >/dev/null` still
  copies stdout through (multios), so use `>/dev/null 2>&1`.
- **Don't decrypt sops to look at a value.** Check key names and lengths only.
- **The user enters secrets, not agents.** Write a script that reads hidden input (`read -rs`),
  pipes it into `sops set --value-stdin` and prints lengths only, then delete the script. The
  user runs it in their own terminal. Random keys can be generated straight into sops.
- **Tools log too.** Before running a tool that may fail, check whether its error output dumps
  request bodies. If it does, fix or redact it first (declarr did this once).
- **If you leak something anyway:** stop, say exactly what was printed and where, and propose
  rotating it. Don't try to hide it.
