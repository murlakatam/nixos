{pkgs, ...}: {
  # system level programs
  programs = {
    #home-manager.enable = true;

    # allow managing GNOME settings through Home Manager
    dconf.enable = true;

    # GNOME Passwords and Keys UI
    # seahorse.enable = false;

    #Allows mounting filesystems that can be accessed by other users, needed for certain applications like AppImages or remote filesystem mounts
    fuse.userAllowOther = true;

    #Network diagnostic tool that combines ping and traceroute
    mtr.enable = true;

    # SSH support, allowing SSH keys to be managed by GnuPG
    # gnupg.agent = {
    #   enable = true;
    #   enableSSHSupport = true;
    # };
  };
}
