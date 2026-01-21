{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    gnomeExtensions.window-calls
  ];

  # 5. Dconf Force Override (The Safety Net)
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions = ["window-calls@swyknox.github.com"];
        };
      };
    }
  ];

  security.polkit.enable = true;
}
