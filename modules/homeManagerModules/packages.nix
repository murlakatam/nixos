{
  pkgs,
  host,
  username,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    azure-cli
    #diff-so-fancy
    cod # turn any --help into completion
    tree # pretty print directories
    fastfetch # flexx your OS : alternative to freshly deceased neofetch
    gimp-with-plugins
    gnome-calculator
    #silver-searcher # ag
    nerd-fonts.jetbrains-mono
    kubelogin # azure kube login
    krusader # total commander alternative
    k9s # k8s management
    lazydocker
    lazygit
    mc
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
    whatsapp-for-linux
    zenity # For winetricks dialogs
  ];
}
