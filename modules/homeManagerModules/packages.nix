{pkgs, ...}: {
  # Run the cod daemon as a service: when many shells start at once (herdr app
  # restoring tabs) each `cod init` races to spawn its own daemon and all but one
  # die on the flock with `"cod daemonize" error: exit status 2`.
  systemd.user.services.cod = {
    Unit.Description = "cod completion daemon";
    Service = {
      ExecStart = "${pkgs.cod}/bin/cod daemon --foreground";
      # cod exits "normally" once its last attached shell closes; bring it back.
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = ["default.target"];
  };

  home.packages = with pkgs; [
    avalonia-ilspy #dotpeek alternative
    bruno # testing puppy
    bruno-cli
    #diff-so-fancy
    cod # turn any --help into completion
    devenv
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
    zenity # For winetricks dialogs 1
  ];
}
