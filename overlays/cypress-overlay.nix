final: prev: {
  #   cypress = prev.cypress.overrideAttrs (oldAttrs: rec {
  #     pname = "cypress";
  #     version = "13.16.1";

  #     src = prev.fetchzip {
  #       url = "https://cdn.cypress.io/desktop/${version}/linux-x64/cypress.zip";
  #       sha256 = "sha256-1x46pgvz53fk5l0dqcq99kcp16lvav6xhbmvd3cpzjhhkd1agjl3";
  #       ## Note: sha256 is computed via (note the version):
  #       ##
  #       ## nix-prefetch-url --unpack https://cdn.cypress.io/desktop/12.17.4/linux-x64/cypress.zip
  #     };
  #   });
}
