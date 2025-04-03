final: prev: {
  azure-artifacts-credprovider-fixed = prev.stdenv.mkDerivation {
    pname = "azure-artifacts-credprovider-fixed";
    version = "1.4.0";

    src = prev.fetchurl {
      url = "https://github.com/microsoft/artifacts-credprovider/releases/download/v1.4.0/Microsoft.Net8.linux-x64.NuGet.CredentialProvider.tar.gz";
      sha256 = "0fgfpakpa9n8qs61lr35mhwsg1caga8n7cn5fycvlvw3nbnnip2x";
    };

    nativeBuildInputs = [prev.makeWrapper];

    unpackPhase = ''
      mkdir -p $out
      tar -xzf $src -C $out
    '';

    installPhase = ''
            # Create the plugin directories
            mkdir -p $out/plugins/netcore

            # Move the files to the correct locations
            cp -r $out/netcore/* $out/plugins/netcore/

            # Clean up the original directories
            rm -rf $out/netcore

            # Create a setup script
            mkdir -p $out/bin
            cat > $out/bin/setup-nuget-auth << EOF
      #!/usr/bin/env bash
      export NUGET_PLUGIN_PATHS="$out/plugins/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll"
      export NUGET_CREDENTIALPROVIDER_PATH="$out/plugins"
      export NUGET_CREDENTIALPROVIDER_SESSIONTOKENCACHE_ENABLED=true
      export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0

      echo "Azure Artifacts Credential Provider configured"
      EOF
            chmod +x $out/bin/setup-nuget-auth
    '';

    meta = with prev.lib; {
      description = "Azure Artifacts Credential Provider for NuGet";
      homepage = "https://github.com/microsoft/artifacts-credprovider";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };
}
