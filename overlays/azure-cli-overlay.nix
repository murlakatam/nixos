self: super: {
  azure-cli = super.azure-cli.overrideAttrs (oldAttrs: {
    doInstallCheck = false;
  });
}
