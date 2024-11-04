{
  pkgs,
  inputs,
  ...
}: {
  imports = with inputs; [
    # Whatever home manager modules go here
    #./hyprland.nix
  ];

  home.username = "eugene";
  home.homeDirectory = "/home/eugene";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    oh-my-zsh
  ];

  programs.firefox = {
    enable = true;
    languagePacks = [
      "en-GB"
      "be"
    ];
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05"; # Did you read the comment?
}
