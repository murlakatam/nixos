{
  pkgs,
  host,
  username,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    oh-my-zsh
    #diff-so-fancy
    zinit # zsh plugin manager
    cod # turn any --help into completion
    tree # pretty print directories
    fastfetch # flexx your OS : alternative to freshly deceased neofetch
    #silver-searcher # ag
    nerd-fonts.jetbrains-mono
    meld # gui differ
    banner # print big banners
    figlet # better banners
    toilet # even better banners
    dust # disk usage for humans
    #yazi # file explorer
    sd # sed for humans
    telegram-desktop
    teams-for-linux
    jetbrains.rider
    jetbrains.webstorm
    azure-cli
    krusader
    # inputs.zen-browser.packages."${pkgs.system}".default
    # inputs.hyprland-qtutils.packages.${pkgs.system}.default
    # inputs.hyprland-qtutils.packages."${pkgs.system}".default
    #glow # markdown previewer in terminal
    #nix-output-monitor # provides `nom` command, works like `nix`

    # (import ../../scripts/emopicker9000.nix { inherit pkgs; })
    # (import ../../scripts/task-waybar.nix { inherit pkgs; })
    # (import ../../scripts/squirtle.nix { inherit pkgs; })
    # (import ../../scripts/nvidia-offload.nix { inherit pkgs; })
    # (import ../../scripts/wallsetter.nix {
    #   inherit pkgs;
    #   inherit username;
    # })
    # (import ../../scripts/web-search.nix { inherit pkgs; })
    # (import ../../scripts/rofi-launcher.nix { inherit pkgs; })
    # (import ../../scripts/screenshootin.nix { inherit pkgs; })
    # (import ../../scripts/list-hypr-bindings.nix {
    #   inherit pkgs;
    #   inherit host;
    # })
  ];
}
