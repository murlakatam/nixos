# Fetches an Azure database access token, prints it, and copies it to the clipboard.
# Prioritizes wl-copy (Wayland) and falls back to xclip (X11).
get-azure-token() {
    echo "Requesting Azure database access token..."

    # Get the token from the Azure CLI and store it in a variable
    local access_token
    access_token=$(az account get-access-token --resource-type oss-rdbms | jq -r '.accessToken')

    # Check if the command was successful and a token was retrieved
    if [[ -z "$access_token" ]]; then
        echo "❌ Failed to retrieve the access token. Please ensure you are logged in to Azure." >&2
        return 1
    fi

    echo "✅ Token successfully retrieved."
    
    # Print the token to the console for visibility
    echo "\nYour Token:"
    echo "--------------------------------------------------"
    echo "$access_token"
    echo "--------------------------------------------------"

    # Check for clipboard utilities, prioritizing wl-copy for Wayland
    if command -v wl-copy &> /dev/null; then
        echo -n "$access_token" | wl-copy
        echo "\n📋 Token has been copied to your clipboard (using wl-copy)."
    elif command -v xclip &> /dev/null; then
        echo -n "$access_token" | xclip -selection clipboard
        echo "\n📋 Token has been copied to your clipboard (using xclip as a fallback)."
    else
        echo "\n⚠️ No clipboard utility found." >&2
        echo "To enable this, add 'wl-clipboard' or 'xclip' to your NixOS configuration and rebuild." >&2
    fi
}