# In your home.nix
{
  config,
  pkgs,
  ...
}: let
  # Define your connection details here for clarity
  #dbHost = "mataersdevtestfpsqlserver.postgres.database.azure.com";
  dbHost = "fakeservername.postgres.database.azure.com";
  dbName = "postgres";
  # The username, still URL-encoded for use in the query string
  #dbUsernameEncoded = "AL%20PSQL%20ERS%20DEVTEST%20READER";
  dbUsernameEncoded = "TEST%20READER";

  # Set the correct path to the file containing your Zsh functions .
  zshFunctionsFile = "${config.home.homeDirectory}/.zshrc";
in {
  xdg.configFile."lazysql/config.toml".text = ''
    # Database connection block for Azure
    [[database]]
    Name = "Azure DevTest DB"
    Provider = "postgres"
    DBName = "postgres"
    # Use the key-value DSN format instead of a URL
    URL = "postgres://${dbUsernameEncoded}:pass@${dbHost}/${dbName}"
    #
    # Commands to run BEFORE connecting
    Commands = [
      { Command = "zsh -c 'source ${zshFunctionsFile}; allow-me-2-postgres'" },
      { Command = "zsh -c 'source ${zshFunctionsFile}; put-azure-token-in-pgpass'" }
    ]

    # Database connection localhost
    [[database]]
    Name = "Local Restored DB"
    Provider = "postgres"
    DBName = "postgres"
    # Use the key-value DSN format instead of a URL
    URL = "postgres://postgres:mysecretpassword@localhost:7452/restored_els_db?sslmode=disable"

    # General application settings (optional)
    [application]
    DefaultPageSize = 300
  '';
}
