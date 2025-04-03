{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    inputs.yazi.packages.${system}.default
    #inputs.nix-inspect.packages.${pkgs.system}.default

    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    alejandra
    azure-artifacts-credprovider
    azuredatastudio
    bat # Cat clone with syntax highlighting
    bitwarden-desktop # password manager
    cypress #cypress
    docker
    dotnetCorePackages.sdk_8_0-bin #dotnet
    git
    google-chrome #chrome
    gparted
    eza # Modern replacement for ls
    ffmpeg_6-full
    iftop # network monitoring
    inxi #system information tool designed for both hardware and system reporting.
    iotop # io monitoring
    jq

    libnotify # notification manager
    nodejs_22 #node
    nodePackages.prettier #node d
    ntfs3g # file system
    pciutils
    pgadmin4-desktopmode
    poppler # pdf redneding lib
    vscode
    usbutils # lsusb
    wget # Network downloader

    # # vim                                               # Text editor (commented out)

    # taplo                                               # TOML formatter and language server

    # #cargo-watch                                        # Watches Rust project files (commented out)
    # #cargo-spellcheck                                   # Spell checker for Rust docs (commented out)

    # vimiv-qt                                            # Image viewer with vim-like keybindings
    # qalculate-gtk                                       # Advanced calculator application
    # meld                                                # Visual diff and merge tool
    # just                                                # Command runner alternative to make
    # inotify-tools                                       # File system monitoring utilities

    # # swayfx                                            # Sway compositor with effects (commented out)
    # # scenefx                                           # Scene effects for Wayland (commented out)

    # wlroots                                             # Wayland compositor library
    # wlr-randr                                           # Screen management tool for wlroots
    # evcxr                                               # Rust REPL (interactive shell)
    # rustup                                              # Rust toolchain installer

    # vulkan-loader                                       # Vulkan API loader
    # vulkan-validation-layers                            # Vulkan validation layers
    # vulkan-tools                                        # Vulkan development tools
    # amdvlk                                              # AMD Vulkan driver

    # profile-sync-daemon                                 # Browser profile sync tool
    # killall                                             # Process termination utility
    # eza                                                 # Modern replacement for ls
    # cmatrix                                             # Terminal-based "Matrix" effect
    # lolcat                                              # Rainbow-colored text output
    # efibootmgr                                          # EFI boot manager
    # htop                                                # Interactive process viewer
    # pokemon-colorscripts-mac                            # Pokemon terminal art
    # libvirt                                             # Virtualization API
    # lxqt.lxqt-policykit                                 # PolicyKit authentication agent
    # lm_sensors                                          # Hardware monitoring tools
    # unzip                                               # Extraction utility for zip files
    # unrar                                               # Extraction utility for rar files
    # libnotify                                           # Desktop notification library
    # v4l-utils                                           # Video4Linux utilities
    # ydotool                                             # Command-line automation tool
    # duf                                                 # Disk usage utility
    # ncdu                                                # Disk usage analyzer with ncurses interface
    # pciutils                                            # PCI utilities
    # ffmpeg                                              # Multimedia framework
    # comma                                               # Run commands from Nix packages without installing
    # socat                                               # Multipurpose relay utility
    # cowsay                                              # Generate ASCII art cows with messages
    # ripgrep                                             # Fast text search tool
    # lshw                                                # Hardware lister
    # bat                                                 # Cat clone with syntax highlighting
    # pkg-config                                          # Helper tool for compiling applications
    # nwg-look                                            # GTK theme configuration tool
    # meson                                               # Build system
    # ninja                                               # Build system
    # virt-viewer                                         # Graphical console client for QEMU
    # appimage-run                                        # AppImage runner

    # markdownlint-cli                                    # Markdown linter CLI
    # markdownlint-cli2                                   # Alternative markdown linter CLI
    # marksman                                            # Markdown language server
    # markdown-oxide                                      # Markdown parser and renderer

    # inxi                                                # System information tool
    # nh                                                  # Nix helper tool
    # nixfmt-rfc-style                                    # Nix code formatter
    # nix-prefetch-git                                    # Prefetch git repositories for Nix
    # nix-prefetch-github                                 # Prefetch GitHub repositories for Nix
    # chafa                                               # Terminal image viewer
    # stdenv                                              # Standard environment for building packages
    # file-roller                                         # Archive manager
    # imv                                                 # Image viewer for Wayland
    # mpv                                                 # Media player
    # gimp                                                # Image editor
    # tree                                                # Directory listing tool
    # cachix                                              # Nix binary cache hosting service client

    # #spotify                                            # Music streaming service (commented out)
    # #neovide                                            # GUI for Neovim (commented out)

    dconf2nix # Convert dconf settings to Nix
    # greetd.tuigreet                                     # Console-based greeter for greetd
    # nodePackages.prettier                               # Code formatter
    # prettierd                                           # Prettier as a daemon
    # ruff                                                # Fast Python linter
    # lazygit                                             # Git terminal UI
    # shfmt                                               # Shell script formatter
    # shellcheck                                          # Shell script static analyzer
    # nixd                                                # Nix language server
    # nodejs_22                                           # Node.js runtime
    # nil                                                 # Nix language server
    # lua-language-server                                 # Lua language server
    # bash-language-server                                # Bash language server
    # stylua                                              # Lua code formatter
    # zig_0_12                                            # Zig programming language
    # unipicker                                           # Unicode character picker
    # nvtopPackages.amd                                   # GPU process monitoring tool for AMD
    # dmidecode                                           # DMI table decoder
    # _7zz                                                # File archiver
    # p7zip                                               # File archiver
    # alsa-utils                                          # ALSA sound utilities
    # nix-diff                                            # Compare Nix derivations
    # manix                                               # Documentation searcher for Nix
    # linuxKernel.packages.linux_zen.cpupower             # CPU power management tool
    # tradingview                                         # Trading and charting platform
    dconf-editor # Configuration editor for dconf
    # rose-pine-cursor                                    # Rose Pine cursor theme
    # pfetch-rs                                           # System information display tool
    # fwupd                                               # Firmware update daemon
    # openssl                                             # Cryptography and SSL/TLS toolkit
    # pkg-config                                          # Helper tool for compiling (duplicate)
    # gccgo14                                             # Go compiler from GCC
    # go                                                  # Go programming language
    # gomuks                                              # Terminal Matrix client
    # olm                                                 # Implementation of Matrix encryption
    # transmission_4-gtk                                  # BitTorrent client
  ];
}
