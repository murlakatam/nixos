{pkgs, ...}: {
  # system level programs
  programs = {
    # allow managing GNOME settings through Home Manager
    dconf.enable = true;
  };
}
