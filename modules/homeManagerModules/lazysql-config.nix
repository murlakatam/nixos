# In your home.nix
{
  config,
  pkgs,
  ...
}: let
  # We will give our connection a service name.
  pgServiceName = "moe_devtest_reader_service";

  # Your connection details, written plainly.
  dbHost = "mataersdevtestfpsqlserver.postgres.database.azure.com";
  dbName = "postgres";
  dbUsername = "AL PSQL ERS DEVTEST READER";

  # Path to your zsh functions file.
  zshFunctionsFile = "${config.home.homeDirectory}/.zshrc";
in {
  # --- Part 1: Create the PostgreSQL Service File ---
  # This file defines connection parameters for a named service.
  # The database driver will read this file automatically.
  # It is typically located at ~/.pg_service.conf
  home.file.".pg_service.conf".text = ''
    [${pgServiceName}]
    host=${dbHost}
    dbname=${dbName}
    user=${dbUsername}
  '';

  # --- Part 2: Configure lazysql to use the Service ---
  xdg.configFile."lazysql/config.toml".text = ''
    [[database]]
    Name = "Azure DevTest DB Reader"
    Provider = "postgres"
    DBName = "${dbName}"

    # --- THE DEFINITIVE FIX ---
    # The URL now simply refers to the service name defined above.
    # This delegates all connection parameter handling to the robust pg driver,
    # completely avoiding the string parsing bug.
    URL = "postgresql://?service=${pgServiceName}"

    # Pre-connection commands remain the same.
    Commands = [
      { Command = "zsh -c 'source ${zshFunctionsFile}; allow-me-2-postgres'" },
      { Command = "zsh -c 'source ${zshFunctionsFile}; put-azure-token-in-pgpass'" }
    ]

    [application]
    DefaultPageSize = 300
  '';
}
