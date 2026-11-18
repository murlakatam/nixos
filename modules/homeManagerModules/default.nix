{...}: {
  imports = [
    ./lazysql-config.nix
    ./wallpapers.nix
    ./programs.nix
    ./packages.nix
    ./custom-scripts.nix
    ./git.nix
    ./flatpak.nix
    ./emoji.nix
    ./zed.nix
    # ./opencode.nix
    ./vscode.nix
    ./ccstatusline
    ./claude-skills.nix
  ];
}
