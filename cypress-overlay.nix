final: prev: {
  cypress = prev.cypress.overrideAttrs (oldAttrs: rec {
    pname = "cypress";
    version = "12.17.4";

    src = prev.fetchzip {
      url = "https://cdn.cypress.io/desktop/${version}/linux-x64/cypress.zip";
      sha256 = "sha256-sf7bIOojUlgRx3QyALBHcI9MIrhxPALbo7S4L2kPhTw=";
      ## Note: sha256 is computed via (note the version):
      ##
      ## nix-prefetch-url --unpack https://cdn.cypress.io/desktop/12.17.4/linux-x64/cypress.zip
    };
  });
}
