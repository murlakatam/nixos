# Allows your current public IP and a provided IP to access the Azure SQL Server.
# It first cleans up ALL old rules starting with "Eugene_WFH_" before creating new ones.
allow-me-2-mssql() {
    # --- NEW: Check for the --skip-login and --add-ip arguments ---
    local skip_login=false
    local additional_ip=""
    
    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--skip-login" ]]; then
            skip_login=true
        elif [[ "$arg" =~ ^--add-ip= ]]; then
            additional_ip="${arg#--add-ip=}"
        fi
    done

    # --- UPDATED: Use the new resource group and server names ---
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
    
    # Update SQL networking rules
    update_mssql_networking() {
        local resource_group=$1
        local server_name=$2
        local ip_address=$3
        local rule_name=$4
        
        echo "Updating SQL server firewall rules..."
        echo "  Resource Group: $resource_group"
        echo "  Server Name:    $server_name"
        echo "  IP Address:     $ip_address"
        
        # --- NEW: Find and delete all old rules matching the pattern ---
        echo "🧹 Searching for and deleting any existing 'Eugene_WFH' rules..."
        local -a old_rules=("${(@f)$(az sql server firewall-rule list \
            --resource-group "$resource_group" \
            --server "$server_name" \
            --query "[?starts_with(name, 'Eugene_WFH')].name" \
            --output tsv)}")

        # --- FIX: Loop through the array safely ---
        if (( ${#old_rules[@]} > 0 )); then
            for old_rule in "${old_rules[@]}"; do
                echo "  -> Deleting old rule: $old_rule"
                az sql server firewall-rule delete \
                    --resource-group "$resource_group" \
                    --server "$server_name" \
                    --name "$old_rule" > /dev/null
            done
            echo "Cleanup complete."
        else
            echo "No old 'Eugene_WFH' rules found to delete."
        fi

        # Create the new firewall rule for today's IP address
        echo "✨ Creating new firewall rule: '$rule_name'"
        az sql server firewall-rule create \
          --resource-group "$resource_group" \
          --server "$server_name" \
          --name "$rule_name" \
          --start-ip-address "$ip_address" \
          --end-ip-address "$ip_address"
        
        if [[ $? -ne 0 ]]; then
            echo "Failed to create SQL server firewall rule with az sql server firewall-rule create --resource-group "$resource_group" --server "$server_name" --name "$rule_name" --start-ip-address "$ip_address" --end-ip-address "$ip_address""
            return 1
        fi
        
        echo "✅ Successfully created firewall rule '$rule_name' for IP address $ip_address"
    }
    
    # --- Main Execution Flow ---
    {
        # Define an array of IPs to process
        local -a ips_to_process=()
        
        echo "Detecting current public IP address..."
        local public_ip
        public_ip=$(get_public_ip)
        
        if [[ -z "$public_ip" ]]; then
            echo "Error: Could not determine public IP address. Cannot proceed." >&2
            return 1
        fi
        echo "Detected public IP: $public_ip"
        ips_to_process+=("$public_ip")
        
        # Add the additional IP if provided
        if [[ -n "$additional_ip" ]]; then
            echo "Adding provided IP: $additional_ip"
            ips_to_process+=("$additional_ip")
        fi

        # Login once before processing all IPs
        if [[ "$skip_login" == true ]]; then
            echo "🔑 Skipping Azure login as requested. Assuming you are already authenticated."
        else
            perform_az_login || return 1
        fi
        
        # Clean up old rules once
        echo "🧹 Searching for and deleting any existing 'Eugene_WFH' rules..."
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
                    --name "$old_rule" \
                    --yes > /dev/null
            done
            echo "Cleanup complete."
        else
            echo "No old 'Eugene_WFH' rules found to delete."
        fi

        # Create new rules for each IP in the array
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
                # We can choose to continue or exit, here we exit on the first failure.
                return 1
            fi
            echo "✅ Successfully created firewall rule '$rule_name' for IP address $ip"
        done
        
        echo "Operation completed successfully."
        
    } || {
        echo "An error occurred during execution." >&2
        return 1
    }
}