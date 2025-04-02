{
  host,
  username,
  ...
}: {
  programs.bash = {
    enable = true;
    enableCompletion = true;
    profileExtra = ''
      #if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
      #  exec Hyprland
      #fi
    '';
    bashrcExtra = ''
      export PATH=$PATH:$HOME/bin:$HOME/.local/bin
      #export PATH=$PATH:$HOME/go/bin
      #export PATH=$PATH:$HOME/.cargo/bin
      #export MANPAGER='nvim +Man!'
    '';
    initExtra = ''
      fastfetch
      if [ -f $HOME/.bashrc-personal ]; then
        source $HOME/.bashrc-personal
      fi
      shopt -s autocd
      eval "$(zoxide init bash)"
      eval "$(mcfly init bash)"
      eval "$(direnv hook bash)"
    '';
    shellAliases = {
      fr = "nh os switch --hostname ${host} /home/${username}/dotfiles/nixos";
      fu = "nh os switch --hostname ${host} --update /home/${username}/dotfiles/nixos";
      ncg = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      cat = "bat";
      ls = "eza --icons";
      ll = "eza -lh --icons --grid --group-directories-first";
      la = "eza -lah --icons --grid --group-directories-first";
      #yz = "yazi";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../../";
    };
  };
}
