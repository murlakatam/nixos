{
  pkgs,
  lib,
  ...
}: let
  omnisharp-path = "${pkgs.omnisharp-roslyn}/bin/OmniSharp";
in {
  # Ensure the necessary packages are installed
  home.packages = [
    pkgs.zed-editor
    (lib.lowPrio pkgs.omnisharp-roslyn)
  ];

  # Configure Zed
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    base_keymap = "JetBrains";
    lsp = {
      omnisharp = {
        binary = {
          path = "${omnisharp-path}";
          arguments = [
            "-lsp"
          ];
        };
      };
    };
  };
}
