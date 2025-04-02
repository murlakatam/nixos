{pkgs, ...}: {
  programs = {
    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [thunar-archive-plugin thunar-volman];
    };
  };

  # Optional: Make Thunar integrate better with GNOME
  environment.systemPackages = with pkgs; [
    gnome.adwaita-icon-theme # For consistent icons
    gtk3.out # For GTK3 theming
  ];

  # Optional: Set Thunar as default file manager
  xdg.mime.defaultApplications = {
    "inode/directory" = "thunar.desktop";
  };
}
