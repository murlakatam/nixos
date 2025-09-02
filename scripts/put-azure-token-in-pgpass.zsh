# ==============================================================================
# put_azure_token_in_pgpass
# ------------------------------------------------------------------------------
# Retrieves an Azure AD access token for PostgreSQL and writes it to the
# appropriate pgpass file for password-less psql connections.
#
# This function requires the Azure CLI (`az`) to be installed and logged in.
# ==============================================================================
function put-azure-token-in-pgpass() {
  # --- Configuration ---
  # Define server hostnames and their corresponding usernames using associative arrays.
  # This makes the mapping clear and easy to manage.
  typeset -A admin_users reader_users
  
  admin_users=(
    "mataersdevtestfpsqlserver.postgres.database.azure.com"   "AL PSQL ERS DEVTEST ADMIN"
    "mapaersuatpreprodfpsqlserver.postgres.database.azure.com" "AL PSQL ERS UATPREPROD ADMIN"
  )
  
  reader_users=(
    "mataersdevtestfpsqlserver.postgres.database.azure.com"   "AL PSQL ERS DEVTEST READER"
    "mapaersuatpreprodfpsqlserver.postgres.database.azure.com" "AL PSQL ERS UATPREPROD READER"
  )

  local port="5432"
  
  # --- Get Azure Token ---
  echo "🔄 Attempting to retrieve Azure AD token for PostgreSQL..."
  
  # Use the Azure CLI to get an access token for OSS RDBMS (PostgreSQL, MySQL, etc.).
  # --output tsv and --query accessToken ensures we get ONLY the token string.
  # 'local' scopes the variable to the function.
  local access_token
  access_token=$(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken 2>/dev/null)
  
  # Error handling: Check if the token was retrieved successfully.
  if [[ -z "$access_token" ]]; then
    echo "❌ Error: Failed to retrieve Azure AD token. Please run 'az login' and try again." >&2
    return 1 # Return with a non-zero exit code to indicate failure
  fi
  echo "✅ Successfully retrieved Azure AD token."

  # --- Build pgpass Entries ---
  # Create an array to hold the lines for the pgpass file.
  local entries=()
  for hostname in "${(@k)admin_users}"; do
    entries+=("${hostname}:${port}:*:${admin_users[$hostname]}:${access_token}")
    entries+=("${hostname}:${port}:*:${reader_users[$hostname]}:${access_token}")
  done

  # --- Determine pgpass File Path ---
  # On Linux/macOS, libpq checks for the PGPASSFILE environment variable first.
  # If it's not set, it defaults to ~/.pgpass. This logic replicates that behavior.
  local pgpass_file="${PGPASSFILE:-$HOME/.pgpass}"
  
  # --- Write to File and Set Permissions ---
  echo "✍️  Writing credentials to $pgpass_file..."
  
  # The `printf` command is a robust way to print each array element on a new line.
  # The `>` operator overwrites the file with the new content.
  printf "%s\n" "${entries[@]}" > "$pgpass_file"
  
  # **CRITICAL**: The pgpass file will be ignored by psql if its permissions are
  # too open. `chmod 600` sets read/write permissions for the owner only.
  chmod 600 "$pgpass_file"
  echo "🔒 Set permissions for $pgpass_file to 600 (read/write for owner only)."
  echo "✨ Done! You can now connect using psql."
}