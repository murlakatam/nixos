# kungfu from upstream master plus 3 security patches not yet merged upstream
# (each header links its upstream issue; drop it once fixed there) and a 4th
# that disables `kungfu update`, which would fight Nix (permanent).
{
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  oniguruma,
  lib,
}:
rustPlatform.buildRustPackage {
  pname = "kungfu";
  version = "2.7.0";

  src = fetchFromGitHub {
    owner = "denyzhirkov";
    repo = "kungfu";
    rev = "6d3a9747e939ced5e3269940e24efdb7de1d36f8";
    hash = "sha256-fRz1bzrHuxHQYkg1Gkl4ywfXXesybcWGFzL5KOwsiKo=";
  };

  patches = [
    ./patches/001-validate-commit-hash.patch
    ./patches/002-validate-memory-id.patch
    ./patches/003-checksum-fail-closed.patch
    ./patches/004-disable-update-subcommand.patch
  ];

  # Upstream's Cargo.lock at the rev above, byte-identical. cargoLock fetches
  # each crate with plain fetchurl; the cargo-vendor util gets 403'd by
  # crates.io's Cloudflare on some networks.
  cargoLock.lockFile = ./patches/Cargo.lock;

  # onig_sys links the system oniguruma and finds it through pkg-config.
  nativeBuildInputs = [pkg-config];
  buildInputs = [oniguruma];

  meta = {
    description = "Code-search and project-context CLI for coding agents";
    homepage = "https://github.com/denyzhirkov/kungfu";
    license = lib.licenses.mit;
    mainProgram = "kungfu";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
