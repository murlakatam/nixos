# In your home.nix
{
  config,
  pkgs,
  ...
}: let
  # Define your connection details here for clarity
  dbHost = "mataersdevtestfpsqlserver.postgres.database.azure.com";
  dbName = "postgres";
  # ❗ In the key-value format, enclose the username in single quotes to protect the spaces.
  dbUsername = "'AL PSQL ERS DEVTEST READER'";

  # Set the correct path to the file containing your Zsh functions.
  zshFunctionsFile = "${config.home.homeDirectory}/.zshrc";
in {
  xdg.configFile."lazysql/config.toml".text = ''
    # Database connection block for your Azure DB
    [[database]]
    Name = "Azure DevTest DB"
    Provider = "postgres"
    DBName = "${dbName}"
    # Use the key-value DSN format instead of a URL
    URL = "host=${dbHost} dbname=${dbName} user=${dbUsername}"
    #
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
