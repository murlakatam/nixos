{pkgs, ...}: {
  # system level programs
  programs = {
    vscode = {
      enable = true;

      # Optional: Install the extension declaratively if you haven't already
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
      ];

      userSettings = {
        # Nix IDE settings
        "nix.enableLanguageServer" = true;

        # POINT 1: Use string interpolation to point to the binary directly
        "nix.formatterPath" = "${pkgs.alejandra}/bin/alejandra";

        # POINT 2: formatting behavior
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
          "editor.formatOnSave" = true;
        };
      };
    };
  };
}
