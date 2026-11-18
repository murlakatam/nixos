# tennis: terminal CSV viewer (not in nixpkgs). callPackage'd by ./default.nix when
# pkgs has no `tennis`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  runCommand,
  zig_0_15,
}: let
  clapSrc = fetchFromGitHub {
    owner = "Hejsil";
    repo = "zig-clap";
    rev = "0.11.0";
    hash = "sha256-XytqwtoE0xaR43YustgK68sAQPVfC0Dt+uCs8UTfkbU=";
  };
  mibuSrc = fetchFromGitHub {
    owner = "xyaman";
    repo = "mibu";
    rev = "b1644432384ac31ffeb45e83d3d3501a911e8865";
    hash = "sha256-jPk7iIPhPtDwprlu7uzHewGTjuqZqJqvJUTkefkfzMs=";
  };
  zcsvSrc = fetchFromGitHub {
    owner = "gurgeous";
    repo = "zig_csv";
    rev = "9960093ec1c50364dfccd26e875791c1571169bc";
    hash = "sha256-86SkDEDeyoOp4RM1eeJyk9oA5seLSLfw2CPk/0jKCW4=";
  };

  # Directory of pre-fetched packages indexed by Zig multihash. Names must
  # exactly match the hashes from tennis's build.zig.zon so `zig build
  # --system` finds them without touching the network.
  zigPackages = runCommand "tennis-zig-packages" {} ''
    mkdir -p $out
    cp -r ${clapSrc} $out/clap-0.11.0-oBajB-HnAQDPCKYzwF7rO3qDFwRcD39Q0DALlTSz5H7e
    cp -r ${mibuSrc} $out/mibu-0.0.1-dev-Ddr1rojEAABcqJWjDNhdeK_CWYjQUZlaGIvJwZOHJWf_
    cp -r ${zcsvSrc} $out/zcsv-0.8.0-Wao6FkGtAgB3tQ1DeyPRnYMLGPIta8FYAPe_XpJlFp4C
  '';
in
  stdenv.mkDerivation {
    pname = "tennis";
    version = "0.0.0";

    src = fetchFromGitHub {
      owner = "gurgeous";
      repo = "tennis";
      rev = "278e49b85caf42f4dbb87aa40be428d6130bf0a7";
      hash = "sha256-UdszJanvPdr0i/DW8OtjPJ6ScovV2K3cOr9AsFKSCfI=";
    };

    # Pin to zig 0.15 — upstream tennis sits in the gap between Zig
    # versions: build.zig uses pre-0.16 Build API (b.graph.env_map,
    # StdIo.Ignore, exe.linkLibC()) so 0.16 breaks evaluation, while
    # src/util.zig uses the 0.15+ writer API (`.init`, `.interface`) so
    # 0.14 breaks compilation. Only 0.15 satisfies both.
    nativeBuildInputs = [zig_0_15];
    dontConfigure = true;

    # --system tells Zig to resolve every dependency from this local
    # directory of pre-hashed packages instead of fetching over the network,
    # which the Nix sandbox forbids.
    buildPhase = ''
      runHook preBuild
      HOME=$TMPDIR \
      ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global-cache \
        zig build --system ${zigPackages} \
                  -Doptimize=ReleaseSafe \
                  --prefix $out
      runHook postBuild
    '';

    dontInstall = true;

    meta = with lib; {
      description = "Terminal CSV viewer written in Zig";
      homepage = "https://github.com/gurgeous/tennis";
      license = licenses.mit;
      mainProgram = "tennis";
      platforms = platforms.linux;
    };
  }
