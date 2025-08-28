# This script is optimized for zsh.
# Allows multiple public IPs to access the Azure SQL Server.
# It first cleans up ALL old rules starting with "Eugene_WFH_" before creating new ones.
allow-me-2-mssql() {
    # --- Check for the --skip-login and --add-ip arguments ---
    local skip_login=false
    local -a additional_ips

    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--skip-login" ]]; then
            skip_login=true
        elif [[ "$arg" =~ ^--add-ip= ]]; then
            # FIX: Use a temporary array to split the string before adding to the main array.
            # This avoids the "error in flags" zsh issue.
            local -a temp_ips=(${(s:,)arg#--add-ip=})
            additional_ips+=("${temp_ips[@]}")
        fi
    done

    # --- Use the new resource group and server names ---
    local RESOURCE_GROUP_NAME="MATA-ERS-DEVTEST-DATABASES"
    local SERVER_NAME="mataersdevtestsqlserver"
    
    # Get public IP address
    get_public_ip() {
        # Fetches only the IP address string
        curl -s https://api.ipify.org
    }

    # Login to Azure
    perform_az_login() {
        echo "Logging in to Azure..."
        
        az login
        if [[ $? -ne 0 ]]; then
            echo "Azure login failed. Please check your credentials and try again." >&2
            return 1
        fi
        echo "Azure login successful."
        az account set --subscription "487387bd-b94b-45e0-a0a8-7ada86aa52e1"
    }

    # --- Main Execution Flow ---
    {
        # Define an array of unique IPs to process
        # The zsh method for handling duplicates is to use a unique array
        local -a ips_to_process

        echo "Detecting current public IP address..."
        local public_ip
        public_ip=$(get_public_ip)
        
        if [[ -z "$public_ip" ]]; then
            echo "Error: Could not determine public IP address. Cannot proceed." >&2
            return 1
        fi
        echo "Detected public IP: $public_ip"
        ips_to_process+=("$public_ip")
        
        # Add the additional IPs
        ips_to_process+=("${additional_ips[@]}")
        
        # Remove duplicates from the array using zsh's unique parameter expansion
        ips_to_process=("${(u)ips_to_process[@]}")

        # Login once before processing all IPs
        if [[ "$skip_login" == true ]]; then
            echo "🔑 Skipping Azure login as requested. Assuming you are already authenticated."
        else
            perform_az_login || return 1
        fi

        # Clean up old rules once
        echo "🧹 Searching for and deleting any existing 'Eugene_WFH' rules..."
        # Use zsh syntax for array splitting
        local -a old_rules=("${(@f)$(az sql server firewall-rule list \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --server "$SERVER_NAME" \
            --query "[?starts_with(name, 'Eugene_WFH')].name" \
            --output tsv)}")

        if (( ${#old_rules[@]} > 0 )); then
            for old_rule in "${old_rules[@]}"; do
                echo "  -> Deleting old rule: $old_rule"
                az sql server firewall-rule delete \
                    --resource-group "$RESOURCE_GROUP_NAME" \
                    --server "$SERVER_NAME" \
                    --name "$old_rule" > /dev/null
            done
            echo "Cleanup complete."
        else
            echo "No old 'Eugene_WFH' rules found to delete."
        fi

        # Create new rules for each unique IP
        for ip in "${ips_to_process[@]}"; do
            local rule_name="Eugene_WFH_$(date +'%Y-%m-%d')_$(echo "$ip" | tr '.' '-')"
            echo "✨ Creating new firewall rule: '$rule_name' for IP $ip"
            az sql server firewall-rule create \
                --resource-group "$RESOURCE_GROUP_NAME" \
                --server "$SERVER_NAME" \
                --name "$rule_name" \
                --start-ip-address "$ip" \
                --end-ip-address "$ip"
            
            if [[ $? -ne 0 ]]; then
                echo "Failed to create firewall rule for IP $ip."
                continue
            fi
            echo "✅ Successfully created firewall rule '$rule_name' for IP address $ip"
        done
        
        echo "Operation completed successfully."
    } || {
        echo "An error occurred during execution." >&2
        return 1
    }
}