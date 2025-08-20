{opencodeSrc, ...}: final: prev: {
  opencode = prev.opencode.overrideAttrs (oldAttrs: {
    src = opencodeSrc;

    # Add Go to the main package's build inputs for the TUI component.
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [prev.go];

    node_modules = oldAttrs.node_modules.overrideAttrs (oldNodeAttrs: {
      # This part is still the correct fix for the C++ native addons.
      buildPhase = ''
        runHook preBuild

        export PATH="${prev.lib.makeBinPath [
          prev.bun
          prev.nodejs_20
          prev.python3
          prev.coreutils
          prev.gnumake
          prev.gcc
        ]}:$PATH"

        bun install --frozen-lockfile

        runHook postBuild
      '';

      outputHash = "sha256-SAz5Py+urnVs2Tx3A/5MkuxVyCqfEQxYaqm0/GbVzF8=";
    });

    tui = oldAttrs.tui.overrideAttrs (tuiOld: {
      src = opencodeSrc;
      vendorHash = "sha256-acDXCL7ZQYW5LnEqbMgDwpTbSgtf4wXnMMVtQI1Dv9s=";
    });

    # Keep the runtime fix.
    postFixup =
      (oldAttrs.postFixup or "")
      + ''
        wrapProgram $out/bin/opencode \
          --set LD_LIBRARY_PATH "${prev.lib.makeLibraryPath [prev.stdenv.cc.cc.lib]}"
      '';
  });
}
#   opencode = prev.stdenv.mkDerivation rec {
#     pname = "opencode";
#     version = "0.5.8";
#     src = prev.fetchFromGitHub {
#       owner = "sst";
#       repo = "opencode";
#       rev = "v${version}";
#       # Set this to the correct hash after a failed build prints it!
#       sha256 = "sha256-SAz5Py+urnVs2Tx3A/5MkuxVyCqfEQxYaqm0/GbVzF8=";
#     };
#     # If you need bun/node packaging or special build steps, customize here.
#     nativeBuildInputs = [prev.nodejs_20 prev.bun prev.go];
#     buildPhase = ''
#       bun install
#       bun run build
#     '';
#     installPhase = ''
#       mkdir -p $out/bin
#       cp path/to/opencode $out/bin/opencode
#       chmod +x $out/bin/opencode
#     '';
#     meta = with prev.lib; {
#       description = "AI coding agent, built for the terminal";
#       homepage = "https://github.com/sst/opencode";
#       license = licenses.mit;
#       platforms = platforms.linux;
#       maintainers = [];
#     };
#   };
# }

