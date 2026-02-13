{pkgs, ...}: {
  home.packages = with pkgs; [
    avalonia-ilspy #dotpeek alternative
    bruno # testing puppy
    bruno-cli
    #diff-so-fancy
    cod # turn any --help into completion
    (lib.hiPrio (with dotnetCorePackages; #dotnet sdk versions
      
        combinePackages [
          sdk_8_0
          sdk_9_0
          sdk_10_0
        ]))
    tree # pretty print directories
    fastfetch # flexx your OS : alternative to freshly deceased neofetch
    gimp-with-plugins
    (google-chrome.override {
      commandLineArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
      ];
    })
    glibcLocales
    gnome-calculator
    #silver-searcher # ag
    kubectl # kubernetes cli
    kubelogin # azure kube login
    krusader # total commander alternative
    k9s # k8s management
    lazydocker
    lazygit
    lazysql
    mc
    mono # .net dev framework
    meld # gui differ
    musicpod #music and podcast player
    pear-desktop # youtube music player
    oscar # cpap software
    banner # print big banners
    figlet # better banners
    toilet # even better banners
    dust # disk usage for humans
    #yazi # file explorer
    sd # sed for humans
    tor-browser # tor browser
    plex-desktop
    telegram-desktop
    teams-for-linux
    jetbrains.datagrip
    jetbrains.goland
    jetbrains.rider
    jetbrains.webstorm
    wasistlos
    zenity # For winetricks dialogs 1
  ];
}
