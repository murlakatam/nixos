final: prev: {
  opencode = prev.stdenv.mkDerivation rec {
    pname = "opencode";
    version = "0.5.8";

    src = prev.fetchFromGitHub {
      owner = "sst";
      repo = "opencode";
      rev = "v${version}";
      # Set this to the correct hash after a failed build prints it!
      sha256 = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
    };

    # If you need bun/node packaging or special build steps, customize here.
    nativeBuildInputs = [prev.nodejs_20 prev.bun prev.go];

    buildPhase = ''
      bun install
      bun run build
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp path/to/opencode $out/bin/opencode
      chmod +x $out/bin/opencode
    '';

    meta = with prev.lib; {
      description = "AI coding agent, built for the terminal";
      homepage = "https://github.com/sst/opencode";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = [];
    };
  };
}
