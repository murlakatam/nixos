{pkgs}: {
  NIX_LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc pkgs.libunwind pkgs.libuuid pkgs.icu pkgs.openssl pkgs.zlib pkgs.curl]}";
  NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";
}
