{
  pkgs,
  osConfig,
  dotfilesPath,
  ...
}: {
  # <--- 1. ADD 'config' HERE so you can use it below

  programs.vscode = {
    enable = true;

    profiles.default = {
      # Optional: Install the extension declaratively
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];

      userSettings = {
        # 1. Enable the Language Server
        nix.enableLanguageServer = true;

        # 2. Point explicitly to the nixd binary
        nix.serverPath = "${pkgs.nixd}/bin/nixd";

        # 3. Configure nixd settings
        nix.serverSettings = {
          nixd = {
            formatting = {
              command = ["${pkgs.alejandra}/bin/alejandra"];
            };

            options = {
              nixos = {
                expr = "(builtins.getFlake \"${dotfilesPath}\").nixosConfigurations.${osConfig.networking.hostName}.options";
              };
            };
          };
        };

        # 4. Standard VS Code settings
        "[nix]" = {
          editor.defaultFormatter = "jnoortheen.nix-ide";
          editor.formatOnSave = true;
        };
      };
    };
  };
}
