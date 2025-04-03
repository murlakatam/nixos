{
  pkgs,
  host,
  username,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    #diff-so-fancy
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
  ];
}
