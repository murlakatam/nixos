# In your home.nix
{
  config,
  pkgs,
  ...
}: let
  # Define your connection details here for clarity
  dbUsername = "AL%20PSQL%20ERS%20DEVTEST%20READER"; # Note: Spaces must be URL-encoded (%20)
  dbServer = "mataersdevtestfpsqlserver.postgres.database.azure.com";
  dbName = "postgres";

  # ❗ IMPORTANT: Set the correct path to the file containing your Zsh functions.
  # This might be .zshrc, .zprofile, or another file.
  zshFunctionsFile = "${config.home.homeDirectory}/.zshrc";
in {
  # This option creates the lazysql config file and writes the content.
  xdg.configFile."lazysql/config.toml".text = ''
    # Database connection block for your Azure DB
    [[database]]
    Name = "Reader ${dbServer}"
    Provider = "postgres"
    DBName = "${dbName}"
    URL = "postgres://${dbUsername}@${dbServer}/${dbName}"
    # Commands to run BEFORE connecting
    Commands = [
      { Command = "zsh -c 'source ${zshFunctionsFile}; allow-me-2-postgres'" },
      { Command = "zsh -c 'source ${zshFunctionsFile}; put-azure-token-in-pgpass'" }
    ]

    # General application settings (optional)
    [application]
    DefaultPageSize = 300
  '';
}
