# File managers. yazi (on by default) with the `y` shell wrapper: it cd's to the dir yazi exits in,
# for every shell HM integrates with (home.shell.enableShellIntegration). Krusader is opt-in: the
# package, archive tools, kdiff3, an optional Kvantum dark Qt theme, and a seeded krusaderrc.
#
# The krusaderrc seed is written only when the file is missing or is still an HM symlink, so
# Krusader's own runtime edits survive. Host-specific paths (left pane dir, editor, terminal,
# mount binary) are options set by the host.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.file-managers;
  kcfg = cfg.krusader;
  home = config.home.homeDirectory;
  str = lib.types.str;
in {
  options.dotfiles.file-managers = {
    enable = lib.mkEnableOption "file managers (yazi, optional krusader)";
    yazi.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Configure yazi with the `y` wrapper (only when dotfiles.file-managers.enable is set).";
    };
    krusader = {
      enable = lib.mkEnableOption "Krusader (with archive tools, kdiff3 and a seeded krusaderrc)";
      kvantum.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use the Kvantum dark Qt style (Linux only; affects all Qt apps).";
      };
      leftDir = lib.mkOption {
        type = str;
        default = home;
        defaultText = lib.literalExpression "config.home.homeDirectory";
        description = "Directory the left pane opens in the seeded krusaderrc.";
      };
      editor = lib.mkOption {
        type = str;
        default = "nvim";
        description = "Editor command in the seeded krusaderrc.";
      };
      terminal = lib.mkOption {
        type = str;
        default = "ghostty";
        description = "Terminal command in the seeded krusaderrc.";
      };
      mountCommand = lib.mkOption {
        type = str;
        default = "/usr/bin/mount";
        description = "mount binary in the seeded krusaderrc (NixOS: /run/wrappers/bin/mount).";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.yazi.enable {
      programs.yazi = {
        enable = true;
        shellWrapperName = "y";
      };
    })

    (lib.mkIf kcfg.enable (lib.mkMerge [
      {
        home.packages = with pkgs; [
          krusader
          # archive/packer tools
          zip
          unzip
          p7zip
          rar
          # diff/merge
          kdiff3
        ];

        home.activation.krusaderConfig = lib.hm.dag.entryAfter ["writeBoundary"] (
          let
            leftUrl = "file://${kcfg.leftDir}";
            rightUrl = "file://${home}";
            seed = pkgs.writeText "krusaderrc" ''
              Config Version=1
              First Time=false
              Version=2.9.0

              [Colors]
              Alternate Background=24,24,37
              Background=30,30,46
              Foreground=205,214,244
              KDE Default=false
              Marked Current Foreground=255,255,255

              [Dependencies]
              mount=${kcfg.mountCommand}

              [General]
              Editor=${kcfg.editor}
              Terminal=${kcfg.terminal}

              [KViewer]
              UseIED=false

              [Private]
              PopularUrls=file://${home}/
              PopularUrlsRank=1
              cmdline history=

              [Startup]
              Left Side Is Active=false
              Show Cmd Line=false
              Show FN Keys=true
              Show Terminal Emulator=false
              Splitter Sizes=521,520
              Terminal Emulator Splitter Sizes=100,100
              Vertical Mode=false

              [Startup][Left Tab Bar]
              ActiveTab=0

              [Startup][Left Tab Bar][Tabs][Tab0]
              PinnedUrl=
              Properties=0
              Type=0
              Url=${leftUrl}

              [Startup][Left Tab Bar][Tabs][Tab0][History]
              CurrentIndex=0
              CurrentItems=..
              Entrys=${leftUrl}

              [Startup][Left Tab Bar][Tabs][Tab0][View]
              AutoResizeColumns=true
              Descending Sort Order=0
              Filter=3
              FilterApplysToDirs=false
              IconSize=22
              ShowPreviews=false
              Sort Column=0

              [Startup][Right Tab Bar]
              ActiveTab=0

              [Startup][Right Tab Bar][Tabs][Tab0]
              PinnedUrl=
              Properties=0
              Type=0
              Url=${rightUrl}

              [Startup][Right Tab Bar][Tabs][Tab0][History]
              CurrentIndex=0
              CurrentItems=..
              Entrys=${rightUrl}

              [Startup][Right Tab Bar][Tabs][Tab0][View]
              AutoResizeColumns=true
              Descending Sort Order=0
              Filter=3
              FilterApplysToDirs=false
              IconSize=22
              ShowPreviews=false
              Sort Column=0

              [Look&Feel]
              Filelist Font=JetBrainsMono Nerd Font,9,-1,5,75,0,0,0,0,0,Bold
              Show splashscreen=false
              Single Instance Mode=true
              Sort method=16

              [ViewerModule]
              FirstRun=false
            '';
          in ''
            _krusaderrc="$HOME/.config/krusaderrc"
            if [ -L "$_krusaderrc" ] || [ ! -f "$_krusaderrc" ]; then
              ${pkgs.coreutils}/bin/install -Dm644 ${seed} "$_krusaderrc"
            fi
          ''
        );
      }

      (lib.mkIf (kcfg.kvantum.enable && pkgs.stdenv.hostPlatform.isLinux) {
        qt = {
          enable = true;
          platformTheme.name = "adwaita";
          style = {
            name = "kvantum-dark";
            package = pkgs.libsForQt5.qtstyleplugin-kvantum;
          };
        };
        xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
          [General]
          theme=KvGnomeDark
        '';
      })
    ]))
  ]);
}
