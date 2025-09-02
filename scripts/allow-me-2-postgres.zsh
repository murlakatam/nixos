# This script is optimized for zsh.
# Allows your current public IP to access the Azure PostgreSQL Flexible Server.
# It first cleans up ALL old rules starting with "Eugene_WFH_" before creating a new one.
allow-me-2-postgres() {
    # --- Check for the --skip-login argument ---
    local skip_login=false
    for arg in "$@"; do
        if [[ "$arg" == "--skip-login" ]]; then
            skip_login=true
        fi
    done

    # --- A dedicated function to sanitize strings ---
    sanitize_string() {
        # Removes newlines, carriage returns, and double quotes from a string
        echo "$1" | tr -d '\n\r\"'
    }

    # --- Use the new resource group and server names ---
    local RESOURCE_GROUP_NAME="MATA-ERS-DEVTEST-PSQL-DATABASES"
    local SERVER_NAME="mataersdevtestfpsqlserver"
    local SUBSCRIPTION_ID="487387bd-b94b-45e0-a0a8-7ada86aa52e1"
    
    # Get public IPv4 address(es) and return a single, clean IP
    get_public_ip() {
        echo "Detecting public IPv4 address..."
        local -a clean_ips
        local -a ip_sources=(https://api.ipify.org https://ifconfig.co/ip https://icanhazip.com https://ipinfo.io/ip)
        
        for source_url in "${ip_sources[@]}"; do
            local public_ip
            public_ip=$(curl -sS --fail "$source_url" || true)
            
            if [[ -n "$public_ip" ]]; then
                # Sanitize the IP at the source, ONCE.
                local clean_ip
                clean_ip=$(sanitize_string "$public_ip")
                
                if [[ "$clean_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    clean_ips+=("$clean_ip")
                    echo "  -> Detected IPv4 from $source_url: $clean_ip"
                fi
            fi
            sleep 0.5
        done

        if [[ ${#clean_ips[@]} -eq 0 ]]; then
            return 1
        fi
        
        # Return only the first unique, clean IP found
        printf "%s\n" "${(u)clean_ips[@]}" | head -n 1
    }

    # Login to Azure
    perform_az_login() {
        if [[ "$skip_login" == true ]]; then echo "🔑 Skipping Azure login as requested."; return 0; fi
        echo "Checking Azure login status..."
        az account show &> /dev/null
        if [[ $? -eq 0 ]]; then
            local current_sub
            current_sub=$(az account show --query id -o tsv)
            if [[ "$current_sub" == "$SUBSCRIPTION_ID" ]]; then
                echo "Already logged in and on the correct subscription."; return 0
            else
                echo "Logged in, but on the wrong subscription. Switching..."
                az account set --subscription "$SUBSCRIPTION_ID"
            fi
        else
            echo "Logging in to Azure..."
            az login --only-show-errors
            if [[ $? -ne 0 ]]; then echo "Azure login failed." >&2; return 1; fi
            az account set --subscription "$SUBSCRIPTION_ID"
        fi
        return 0
    }
    
    # --- Main Execution Flow ---
    {
        local public_ip
        public_ip=$(get_public_ip)
        
        if [[ -z "$public_ip" ]]; then
            echo "Error: Could not determine public IP address. Cannot proceed." >&2
            return 1
        fi
        echo "✅ Detected public IP: $public_ip"
        
        # Create a unique rule name that includes the IP address
        local rule_name="Eugene_WFH_$(date +'%Y-%m-%d')_$(echo "$public_ip" | tr '.' '-')"
        
        perform_az_login || return 1

        echo "🧹 Searching for and deleting any existing 'Eugene_WFH' rules..."
        
        # Get a list of old rule names
        local old_rules_str
        old_rules_str=$(az postgres flexible-server firewall-rule list \
            -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" \
            --query "[?starts_with(name, 'Eugene_WFH')].name" -o tsv)

        if [[ -n "$old_rules_str" ]]; then
            # Loop through each rule name found and delete it
            while IFS= read -r old_rule; do
                if [[ -n "$old_rule" ]]; then
                    echo "  -> Deleting old rule: $old_rule"
                    az postgres flexible-server firewall-rule delete \
                        -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" \
                        --rule-name "$old_rule" --yes --only-show-errors > /dev/null
                fi
            done <<< "$old_rules_str"
            echo "Cleanup complete."
        else
            echo "No old 'Eugene_WFH' rules found to delete."
        fi

        # Create the new firewall rule
        echo "✨ Creating new firewall rule: '$rule_name' for IP $public_ip"
        az postgres flexible-server firewall-rule create \
          -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" \
          -n "$rule_name" \
          --start-ip-address "$public_ip" \
          --end-ip-address "$public_ip" \
          --only-show-errors > /dev/null
        
        echo "✅ Operation completed successfully."
        
    } || {
        echo "❌ An error occurred during execution." >&2
        return 1
    }
}