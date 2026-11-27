{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
  python3,
  zeromq,
  makeWrapper,
  node-gyp,
}:
buildNpmPackage {
  pname = "public-pool";
  version = "0-unstable-2026-06-05";

  src = fetchFromGitHub {
    owner = "benjamin-wilson";
    repo = "public-pool";
    rev = "96a9202c11de2c6fc8d41155e2e779912a476dc7";
    hash = "sha256-9nyMdw86J7alWGVh3X8q1zU0McLuMTjdvn/sf93qXfk=";
  };

  npmDepsHash = "sha256-NpP/m+6+XxBumBcwdM812T80wDgUlLmQC3069VWmiwY=";

  nodejs = nodejs_24;
  nativeBuildInputs = [python3 makeWrapper node-gyp];
  buildInputs = [zeromq];

  # sqlite3: compile its bundled amalgamation instead of fetching a prebuild.
  env.npm_config_build_from_source = "true";

  # zeromq's install script keeps its bundled prebuild, so build it here against
  # nixpkgs' shared libzmq (zmq_shared skips the libzmq source download).
  preBuild = ''
    pushd node_modules/zeromq
    rm -rf prebuilds
    node-gyp configure --nodedir=${nodejs_24} -- -Dzmq_shared=true
    node-gyp build --nodedir=${nodejs_24}
    popd
  '';

  # The package.json has no "files" list and .gitignore excludes dist/, so install by hand.
  installPhase = ''
    runHook preInstall
    npm prune --omit=dev --no-audit --no-fund
    mkdir -p $out/lib/public-pool $out/bin
    cp -r dist node_modules package.json $out/lib/public-pool/
    # secrets/ (upstream's TLS key) is deliberately not copied; keep API_SECURE=false.
    # Runs from the caller's cwd: the DB path ./DB/public-pool.sqlite is relative to it.
    makeWrapper ${lib.getExe nodejs_24} $out/bin/public-pool \
      --add-flags $out/lib/public-pool/dist/main
    runHook postInstall
  '';

  meta = {
    description = "Open-source Bitcoin solo mining pool (stratum v1)";
    homepage = "https://github.com/benjamin-wilson/public-pool";
    license = lib.licenses.gpl3Only;
    mainProgram = "public-pool";
    platforms = lib.platforms.linux;
  };
}
