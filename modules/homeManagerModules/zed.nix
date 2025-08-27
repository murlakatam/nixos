{pkgs, ...}: let
  omnisharp-path = "${pkgs.omnisharp-roslyn}/bin/OmniSharp.dll";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0-bin;
in {
  # Ensure the necessary packages are installed
  home.packages = [
    pkgs.zed-editor
    pkgs.omnisharp-roslyn
  ];

  # Configure Zed
  xdg.configFile."zed/settings.json".text = builtins.toJSON {
    lsp = {
      omnisharp = {
        binary = {
          path = "${dotnet-sdk}/bin/dotnet";
          arguments = [
            omnisharp-path
            "-lsp"
          ];
        };
      };
    };
  };
}
