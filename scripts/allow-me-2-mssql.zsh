# This script is optimized for zsh.
# Allows multiple public IPs to access the Azure SQL Server.
# It uses a diff-based approach to only add or remove rules that are different from the current state.
allow-me-2-mssql() {
    # --- Check for the --skip-login and --add-ip arguments ---
    local skip_login=false
    local -a additional_ips
    local -A detected_ips # Using a hash to store unique IPs from multiple curl calls
    
    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--skip-login" ]]; then
            skip_login=true
        elif [[ "$arg" =~ ^--add-ip= ]]; then
            local ips_string="${arg#--add-ip=}"
            IFS=',' read -r -A new_ips <<< "$ips_string"
            additional_ips+=("${new_ips[@]}")
        fi
    done

    # --- Use the new resource group and server names ---
    local RESOURCE_GROUP_NAME="MATA-ERS-DEVTEST-DATABASES"
    local SERVER_NAME="mataersdevtestsqlserver"
    local SUBSCRIPTION_ID="487387bd-b94b-45e0-a0a8-7ada86aa52e1"
    
    # Get public IPv4 address(es)
    get_public_ips() {
        echo "Detecting public IPv4 address..."
        # Simplified the loop for clarity
        local -a ip_sources=(https://api.ipify.org https://ifconfig.co/ip https://icanhazip.com https://ipinfo.io/ip)
        for source_url in "${ip_sources[@]}"; do
            local public_ip
            public_ip=$(curl -sS --fail "$source_url" || true)
            if [[ -n "$public_ip" ]]; then
                public_ip=$(echo "$public_ip" | tr -d '\n\r') # Remove newlines/carriage returns
                # Only process valid IPv4 addresses
                if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    detected_ips["$public_ip"]=1
                    echo "  -> Detected IPv4 from $source_url: $public_ip"
                fi
            fi
            sleep 0.5 # Small delay
        done

        if [[ ${#detected_ips[@]} -eq 0 ]]; then
            echo "Error: Could not determine any public IPv4 address. Cannot proceed." >&2
            return 1
        fi
        
        echo "Finished detecting IPs. Unique IPs found: ${(k)detected_ips}"
        return 0
    }

    # Login to Azure
    perform_az_login() {
        if [[ "$skip_login" == true ]]; then
            echo "🔑 Skipping Azure login as requested. Assuming you are already authenticated."
            return 0
        fi
        
        echo "Checking Azure login status..."
        az account show &> /dev/null
        if [[ $? -eq 0 ]]; then
            local current_sub=$(az account show --query id -o tsv)
            if [[ "$current_sub" == "$SUBSCRIPTION_ID" ]]; then
                echo "Already logged in and on the correct subscription."
                return 0
            else
                echo "Logged in, but on the wrong subscription. Switching..."
                az account set --subscription "$SUBSCRIPTION_ID"
            fi
        else
            echo "Logging in to Azure..."
            az login --only-show-errors
            if [[ $? -ne 0 ]]; then
                echo "Azure login failed. Please check your credentials." >&2
                return 1
            fi
            echo "Azure login successful. Setting subscription..."
            az account set --subscription "$SUBSCRIPTION_ID"
        fi
        return 0
    }

    # --- Main Execution Flow ---
    {
        # Define arrays for desired and existing rules
        local -a desired_ips_array
        local -A desired_rules_map # Map of IP to rule name
        local -A existing_rules_map # Map of IP to rule name

        # 1. Get current and additional IPs
        get_public_ips || return 1
        desired_ips_array=("${(k)detected_ips[@]}")
        
        # Add additional IPv4 addresses and remove duplicates
        for ip in "${additional_ips[@]}"; do
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                desired_ips_array+=("$ip")
            else
                echo "Warning: Ignoring non-IPv4 address in --add-ip argument: $ip"
            fi
        done
        desired_ips_array=("${(u)desired_ips_array[@]}") # Remove duplicates

        # Generate a rule name for each desired IP
        for ip in "${desired_ips_array[@]}"; do
            local rule_name="Eugene_WFH_$(date +'%Y-%m-%d')_$(echo "$ip" | tr '.' '-')"
            desired_rules_map["$ip"]="$rule_name"
        done

        # 2. Authenticate with Azure
        perform_az_login || return 1

        # 3. Get existing firewall rules
        echo "🔍 Fetching existing 'Eugene_WFH' rules from Azure..."
        local existing_rules_json
        existing_rules_json=$(az sql server firewall-rule list \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --server "$SERVER_NAME" \
            --query "[?starts_with(name, 'Eugene_WFH') && startIpAddress == endIpAddress].{name:name, ip:startIpAddress}" \
            --output json 2>/dev/null)

        # Use a more robust `while read` loop to parse the JSON
        if [[ -n "$existing_rules_json" ]]; then
            echo "$existing_rules_json" | jq -c '.[]' | while IFS= read -r rule_entry; do
                local name=$(echo "$rule_entry" | jq -r '.name')
                local ip=$(echo "$rule_entry" | jq -r '.ip')
                if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    existing_rules_map["$ip"]="$name"
                fi
            done
        fi
        
        # 4. Determine which rules to add and which to delete using associative array lookups
        # This is more robust than using `comm`.
        local -a ips_to_add
        local -a ips_to_delete

        # Find IPs that are desired but don't exist yet
        for ip in "${(@k)desired_rules_map}"; do
            if [[ -z "${existing_rules_map[$ip]}" ]]; then
                ips_to_add+=("$ip")
            fi
        done

        # Find IPs that exist but are no longer desired
        for ip in "${(@k)existing_rules_map}"; do
            if [[ -z "${desired_rules_map[$ip]}" ]]; then
                ips_to_delete+=("$ip")
            fi
        done

        # 5. Execute changes
        
        # Add new rules
        if (( ${#ips_to_add[@]} > 0 )); then
            echo "✨ Creating new rules for missing IPs..."
            for ip in "${ips_to_add[@]}"; do
                local rule_name="${desired_rules_map[$ip]}"
                echo "  -> Adding rule: '$rule_name' for IP $ip"
                az sql server firewall-rule create \
                    --resource-group "$RESOURCE_GROUP_NAME" \
                    --server "$SERVER_NAME" \
                    --name "$rule_name" \
                    --start-ip-address "$ip" \
                    --end-ip-address "$ip" \
                    --only-show-errors > /dev/null
            done
        else
            echo "🎉 All desired IPs already have firewall rules. No new rules to create."
        fi

        # Delete old rules
        if (( ${#ips_to_delete[@]} > 0 )); then
            echo "🧹 Deleting old rules for stale IPs..."
            for ip in "${ips_to_delete[@]}"; do
                local rule_name="${existing_rules_map[$ip]}"
                echo "  -> Deleting rule: '$rule_name' for IP $ip"
                az sql server firewall-rule delete \
                    --resource-group "$RESOURCE_GROUP_NAME" \
                    --server "$SERVER_NAME" \
                    --name "$rule_name" \
                    --only-show-errors > /dev/null
            done
        else
            echo "🧹 No stale 'Eugene_WFH' rules found to delete."
        fi

        echo "✅ Operation completed successfully."
    } || {
        echo "❌ An error occurred during execution." >&2
        return 1
    }
}