{pkgs, ...}: {
  # Place Files Inside Home Directory
  home.file."Pictures/Wallpapers" = {
    source = ../wallpapers;
    recursive = true;
  };
}
