# overlays/netpad-overlay.nix
final: prev: {
  netpad = prev.buildDotnetModule rec {
    pname = "netpad";
    version = "0.10.0";

    src = prev.fetchFromGitHub {
      owner = "tareqimbasher";
      repo = "NetPad";
      rev = "v${version}";
      # IMPORTANT: Replace this with the real sha256 you calculate!
      sha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    };

    # Point to the specific project file for the Electron app
    projectFile = "src/Apps/NetPad.Electron/NetPad.Electron.csproj";

    # Use vendorHash instead of nugetDeps.
    # First, leave it empty (""). Nix will fail and tell you the correct hash.
    # Then, copy the correct hash here.
    vendorHash = "sha256-YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY=";

    # NetPad v0.10.0 uses the .NET 8 SDK
    dotnet-sdk = prev.dotnetCorePackages.sdk_8_0;

    # Add runtime dependencies needed for an Electron GUI application
    runtimeDeps = with prev; [gtk3 webkitgtk_4_1];

    meta = with prev.lib; {
      description = "A cross-platform, modern, and powerful .NET script runner.";
      homepage = "https://netpad.dev/";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = with maintainers; [your-github-username]; # Good practice to add yourself
    };
  };
}
