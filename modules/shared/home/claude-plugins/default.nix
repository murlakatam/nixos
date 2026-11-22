# Generic Claude Code plugins, loaded from the Nix store via ai.claudeCode.pluginDirs.
# The consumer passes each source, because shared modules take no flake inputs.
# A plugin is on when its src is set. Language servers must already be on PATH.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.claude-plugins;
  srcOpt = desc:
    lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "${desc} source. Null leaves the plugin off.";
    };

  # Its hooks run a bare `node`, which is not on PATH.
  ponytail = pkgs.runCommand "claude-plugin-ponytail" {} ''
    cp -r ${cfg.ponytail.src} $out
    chmod -R u+w $out
    substituteInPlace $out/hooks/claude-codex-hooks.json \
      --replace-fail '"command": "node -e' '"command": "${pkgs.nodejs_24}/bin/node -e'
  '';

  # Upstream opens its pages with macOS `open`.
  showMe = pkgs.runCommand "claude-plugin-show-me" {} ''
    cp -r ${cfg.showMe.src}/plugins/show-me $out
    chmod -R u+w $out
    substituteInPlace $out/skills/show-me/SKILL.md \
      --replace-fail 'Bash(open path/to/show-me-{description}.html)' 'Bash(xdg-open path/to/show-me-{description}.html)'
  '';

  lsp = pkgs.linkFarm "claude-plugin-lsp" [
    {
      name = ".claude-plugin/plugin.json";
      path = pkgs.writeText "plugin.json" (builtins.toJSON {
        name = "dotfiles-lsp";
        version = "1.0.0";
        description = "TypeScript, C# and Python language servers from PATH.";
      });
    }
    {
      name = ".lsp.json";
      path = pkgs.writeText "lsp.json" (builtins.toJSON {
        typescript = {
          command = "typescript-language-server";
          args = ["--stdio"];
          extensionToLanguage = {
            ".ts" = "typescript";
            ".tsx" = "typescriptreact";
            ".js" = "javascript";
            ".jsx" = "javascriptreact";
            ".mts" = "typescript";
            ".cts" = "typescript";
            ".mjs" = "javascript";
            ".cjs" = "javascript";
          };
        };
        csharp-ls = {
          command = "csharp-ls";
          extensionToLanguage.".cs" = "csharp";
        };
        pylsp = {
          command = "pylsp";
          extensionToLanguage.".py" = "python";
        };
      });
    }
  ];
in {
  imports = [../ai-permissions];

  options.dotfiles.claude-plugins = {
    enable = lib.mkEnableOption "generic Claude Code plugins";
    obsidianSkills.src = srcOpt "kepano/obsidian-skills";
    showMe.src = srcOpt "humanlayer/skills (only its show-me plugin is used)";
    ponytail.src = srcOpt "DietrichGebert/ponytail";
    lsp.enable = lib.mkEnableOption "native LSP servers for TypeScript, C# and Python";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf (cfg.obsidianSkills.src != null) {
      ai.claudeCode.pluginDirs = ["${cfg.obsidianSkills.src}/plugins/obsidian"];
    })
    (lib.mkIf (cfg.showMe.src != null) {
      ai.claudeCode.pluginDirs = ["${showMe}"];
      ai.permissions.claudeCode.allowedTools = ["Bash(xdg-open *)" "Bash(mermaid-show *)" "Bash(mmdc *)"];
    })
    (lib.mkIf (cfg.ponytail.src != null) {
      ai.claudeCode.pluginDirs = ["${ponytail}"];
    })
    (lib.mkIf cfg.lsp.enable {
      ai.claudeCode.pluginDirs = ["${lsp}"];
      ai.claudeCode.extraEnv.ENABLE_LSP_TOOL = "1";
    })
  ]);
}
