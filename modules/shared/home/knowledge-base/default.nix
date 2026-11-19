# Knowledge base: the Obsidian app plus git-backed vaults, cloned on activation and synced by a
# systemd user timer.
#
#   dotfiles.knowledge-base = {
#     enable = true;
#     vaults.brain = {path = "/home/me/docs/brain"; remote = "git@github.com:me/brain.git";};
#   };
#
# Per vault:
#   - activation clones `remote` into `path` when the path is missing (never fails activation;
#     an empty remote is skipped). An existing repo and its origin are never rewritten.
#   - `kb-sync-<name>` (also run by the timer): commit local changes, fetch, rebase onto the
#     remote, push. A rebase conflict aborts the rebase, notifies and pushes nothing; files over
#     sync.maxFileSizeMB stop the sync before committing. An unreachable remote is a no-op.
#   - managed ignores (Obsidian workspace/cache, trash, tool caches) go to .git/info/exclude, so
#     nothing is committed into the vault by Nix.
# The vault's own .obsidian settings and plugins stay in the vault; host-specific plugins and GPU
# wrappers (nixGL on non-NixOS: set obsidian.package) are host-side.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.knowledge-base;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  excludeBlock = pkgs.writeText "kb-exclude" ''
    # >>> dotfiles.knowledge-base (managed, rewritten on every sync)
    .obsidian/workspace*.json
    .obsidian/cache
    .trash/
    .omc/
    .mypy_cache/
    __pycache__/
    .DS_Store
    *.sqlite
    *.sqlite-*
    # <<< dotfiles.knowledge-base
  '';

  gitSsh = "ssh -o BatchMode=yes -o ConnectTimeout=15";

  mkClone = name: v:
    pkgs.writeShellApplication {
      name = "kb-clone-${name}";
      runtimeInputs = [pkgs.git pkgs.openssh pkgs.coreutils];
      text = ''
        export GIT_SSH_COMMAND=${lib.escapeShellArg gitSsh}
        vault=${lib.escapeShellArg v.path}
        remote=${lib.escapeShellArg (toString v.remote)}
        [ -e "$vault" ] && exit 0
        if ! heads="$(timeout 30 git ls-remote --heads "$remote")"; then
          echo "kb-clone-${name}: $remote unreachable; not cloning $vault" >&2
          exit 1
        fi
        if [ -z "$heads" ]; then
          echo "kb-clone-${name}: $remote is empty; not cloning $vault yet" >&2
          exit 0
        fi
        mkdir -p "$(dirname "$vault")"
        timeout 300 git clone --quiet "$remote" "$vault"
        echo "kb-clone-${name}: cloned $remote into $vault"
      '';
    };

  mkSync = name: v:
    pkgs.writeShellApplication {
      name = "kb-sync-${name}";
      runtimeInputs = [pkgs.git pkgs.openssh pkgs.coreutils pkgs.gnused pkgs.util-linux pkgs.libnotify];
      text = ''
        export GIT_SSH_COMMAND=${lib.escapeShellArg gitSsh}
        vault=${lib.escapeShellArg v.path}
        maxBytes=$(( ${toString v.sync.maxFileSizeMB} * 1024 * 1024 ))

        alert() {
          echo "kb-sync-${name}: $1" >&2
          notify-send -u critical "Vault sync: ${name}" "$1" 2>/dev/null || true
        }

        if [ ! -e "$vault" ]; then
          ${
          if v.remote != null
          then ''${mkClone name v}/bin/kb-clone-${name} || exit 0''
          else ''echo "kb-sync-${name}: $vault missing" >&2''
        }
          [ -e "$vault" ] || exit 0
        fi
        if [ ! -d "$vault/.git" ]; then
          alert "$vault is not a git repository"
          exit 1
        fi
        cd "$vault"

        exec 9>".git/kb-sync.lock"
        flock -n 9 || { echo "kb-sync-${name}: already running"; exit 0; }

        ${lib.optionalString v.gitignore.enable ''
          mkdir -p .git/info
          touch .git/info/exclude
          sed -i '/^# >>> dotfiles.knowledge-base/,/^# <<< dotfiles.knowledge-base/d' .git/info/exclude
          cat ${excludeBlock} >> .git/info/exclude
        ''}

        if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
          alert "a rebase/merge is in progress in $vault; resolve it by hand"
          exit 1
        fi

        # Headless hosts may have no git identity: fall back to a per-host sync author.
        ident=()
        if [ -z "$(git config user.email || true)" ]; then
          h="$(uname -n)"
          ident=(-c "user.name=kb-sync ($h)" -c "user.email=kb-sync@$h")
        fi

        if [ -n "$(git status --porcelain)" ]; then
          git add -A
          big=""
          while IFS= read -r -d "" f; do
            [ -f "$f" ] || continue
            if [ "$(stat -c %s "$f")" -gt "$maxBytes" ]; then big="$big $f"; fi
          done < <(git diff --cached --name-only --diff-filter=AM -z)
          if [ -n "$big" ]; then
            git reset --quiet
            alert "files over ${toString v.sync.maxFileSizeMB} MB, not syncing:$big"
            exit 1
          fi
          git "''${ident[@]}" commit --quiet -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
        fi

        if ! git rev-parse -q --verify HEAD >/dev/null; then
          echo "kb-sync-${name}: nothing committed yet"
          exit 0
        fi
        branch="$(git symbolic-ref --short HEAD)"

        if ! timeout 120 git fetch --quiet origin; then
          echo "kb-sync-${name}: remote unreachable; will retry" >&2
          exit 0
        fi
        if git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
          if ! git "''${ident[@]}" rebase --quiet "origin/$branch"; then
            git rebase --abort || true
            alert "conflict rebasing $vault onto origin/$branch; local commits kept, nothing pushed"
            exit 1
          fi
        fi
        if [ "$(git rev-parse HEAD)" != "$(git rev-parse -q --verify "refs/remotes/origin/$branch" || true)" ]; then
          timeout 120 git push --quiet origin "HEAD:$branch" || { alert "push to origin/$branch failed"; exit 1; }
          echo "kb-sync-${name}: pushed $branch"
        fi
      '';
    };

  vaultType = lib.types.submodule ({config, ...}: {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path of the vault.";
      };
      remote = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Git remote to clone from when `path` is missing. An existing repo's origin is left alone.";
      };
      sync = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = config.remote != null;
          defaultText = lib.literalExpression "remote != null";
          description = "Run kb-sync-<name> on a systemd user timer (Linux).";
        };
        onCalendar = lib.mkOption {
          type = lib.types.str;
          default = "hourly";
          description = "systemd OnCalendar for the sync timer.";
        };
        maxFileSizeMB = lib.mkOption {
          type = lib.types.ints.positive;
          default = 20;
          description = "Refuse to commit new or changed files larger than this.";
        };
      };
      gitignore.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Write the managed ignore list to .git/info/exclude on each sync.";
      };
    };
  });

  syncedVaults = lib.filterAttrs (_: v: v.sync.enable) cfg.vaults;
  clonedVaults = lib.filterAttrs (_: v: v.remote != null) cfg.vaults;
in {
  options.dotfiles.knowledge-base = {
    enable = lib.mkEnableOption "knowledge base (Obsidian + git-synced vaults)";
    obsidian = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install Obsidian (only when dotfiles.knowledge-base.enable is set).";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = pkgs.obsidian;
        defaultText = lib.literalExpression "pkgs.obsidian";
        description = "Obsidian package; a GPU wrapper on non-NixOS, or null to install it elsewhere.";
      };
    };
    vaults = lib.mkOption {
      type = lib.types.attrsOf vaultType;
      default = {};
      description = "Vaults by name (the name is used in kb-sync-<name> and its systemd units).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optional (cfg.obsidian.enable && cfg.obsidian.package != null) cfg.obsidian.package
      ++ lib.mapAttrsToList mkSync cfg.vaults;

    home.activation.knowledgeBaseClone = lib.mkIf (clonedVaults != {}) (
      lib.hm.dag.entryAfter ["writeBoundary"] (lib.concatStrings (lib.mapAttrsToList (name: v: ''
          run ${mkClone name v}/bin/kb-clone-${name} \
            || echo "knowledge-base: ${name} not cloned now; kb-sync-${name} retries" >&2
        '')
        clonedVaults))
    );

    systemd.user = lib.mkIf (isLinux && syncedVaults != {}) {
      services = lib.mapAttrs' (name: v:
        lib.nameValuePair "kb-sync-${name}" {
          Unit.Description = "Git sync of the ${name} vault";
          Service = {
            Type = "oneshot";
            ExecStart = "${mkSync name v}/bin/kb-sync-${name}";
          };
        })
      syncedVaults;
      timers = lib.mapAttrs' (name: v:
        lib.nameValuePair "kb-sync-${name}" {
          Unit.Description = "Git sync of the ${name} vault";
          Install.WantedBy = ["timers.target"];
          Timer = {
            OnCalendar = v.sync.onCalendar;
            Persistent = true;
          };
        })
      syncedVaults;
    };
  };
}
