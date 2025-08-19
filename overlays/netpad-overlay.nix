final: prev: {
  netpad = prev.buildDotnetModule rec {
    pname = "netpad";
    version = "0.10.0";

    src = prev.fetchFromGitHub {
      owner = "tareqimbasher";
      repo = "NetPad";
      rev = "v0.10.0";
      sha256 = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; # update after `nix-prefetch`
    };

    projectFile = "NetPad.sln"; # or the correct *.csproj for entrypoint

    # You must generate this file with `nix-build -A netpad.fetch-deps`.
    nugetDeps = ./deps.nix;

    dotnet-sdk = prev.dotnetCorePackages.sdk_9_0; # adjust to match NetPad requirements

    # Optional: add runtimeDeps for Tauri/Electron (like GTK, Webkit, etc.) depending on exact build
    # runtimeDeps = [ prev.gtk3 prev.webkitgtk ];

    meta = with prev.lib; {
      description = "Modern script-oriented .NET code runner with database support";
      homepage = "https://github.com/tareqimbasher/NetPad";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };
}
