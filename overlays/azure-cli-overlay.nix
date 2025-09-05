self: super: {
  azure-cli = super.azure-cli.overrideAttrs (oldAttrs: {
    propagatedBuildInputs =
      oldAttrs.propagatedBuildInputs
      ++ [
        self.python3.pkgs.azure-mgmt-containerservice
      ];
  });
}
