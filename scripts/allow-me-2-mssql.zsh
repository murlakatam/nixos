# Allows multiple public IPs to access the Azure SQL Server.
# It first cleans up ALL old rules starting with "Eugene_WFH_" before creating new ones.
allow-me-2-mssql() {
    # --- Check for the --skip-login and --add-ip arguments ---
    local skip_login=false
    local additional_ips=()

    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--skip-login" ]]; then
            skip_login=true
        elif [[ "$arg" =~ ^--add-ip= ]]; then
            # Split the argument by commas and add to the array
            IFS=',' read -r -a new_ips <<< "${arg#--add-ip=}"
            additional_ips+=("${new_ips[@]}")
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
        # Define a set of IPs to process using a declare -A for unique keys
        declare -A ips_to_process

        echo "Detecting current public IP address..."
        local public_ip
        public_ip=$(get_public_ip)
        
        if [[ -z "$public_ip" ]]; then
            echo "Error: Could not determine public IP address. Cannot proceed." >&2
            return 1
        fi
        echo "Detected public IP: $public_ip"
        ips_to_process["$public_ip"]=1

        # Add the additional IPs if provided, avoiding duplicates
        if (( ${#additional_ips[@]} > 0 )); then
            for ip in "${additional_ips[@]}"; do
                if [[ -n "$ip" ]]; then
                    echo "Adding provided IP: $ip"
                    ips_to_process["$ip"]=1
                fi
            done
        fi

        # Login once before processing all IPs
        if [[ "$skip_login" == true ]]; then
            echo "🔑 Skipping Azure login as requested. Assuming you are already authenticated."
        else
            perform_az_login || return 1
        fi

        # Clean up old rules once
        echo "🧹 Searching for and deleting any existing 'Eugene_WFH' rules..."
        # FIX: Replaced zsh specific syntax with a bash-compatible method
        local old_rules_string
        old_rules_string=$(az sql server firewall-rule list \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --server "$SERVER_NAME" \
            --query "[?starts_with(name, 'Eugene_WFH')].name" \
            --output tsv)
        
        # Read the newline-separated string into a bash array
        IFS=$'\n' read -r -a old_rules <<< "$old_rules_string"

        if (( ${#old_rules[@]} > 0 )); then
            for old_rule in "${old_rules[@]}"; do
                echo "  -> Deleting old rule: $old_rule"
                # FIX: Removed the unsupported --yes flag
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
        for ip in "${!ips_to_process[@]}"; do
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