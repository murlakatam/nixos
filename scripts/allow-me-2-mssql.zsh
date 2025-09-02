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
        local -a ip_sources=(https://api.ipify.org https://ifconfig.co/ip https://icanhazip.com https://ipinfo.io/ip)
        for source_url in "${ip_sources[@]}"; do
            local public_ip
            public_ip=$(curl -sS --fail "$source_url" || true)
            
            # --- TRACE POINT 1: RAW OUTPUT FROM CURL ---
            printf "[TRACE 1 RAW CURL] from %s is: %q\n" "$source_url" "$public_ip"

            if [[ -n "$public_ip" ]]; then
                public_ip="${public_ip//$'\r'/}"
                public_ip="${public_ip//$'\n'/}"
                public_ip="${public_ip//\"/}"

                # --- TRACE POINT 2: AFTER SANITIZING ---
                printf "[TRACE 2 SANITIZED] %q\n" "$public_ip"
                
                if [[ "$public_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    detected_ips["$public_ip"]=1
                    echo "  -> Detected IPv4 from $source_url: $public_ip"
                fi
            fi
            sleep 0.5
        done

        if [[ ${#detected_ips[@]} -eq 0 ]]; then
            echo "Error: Could not determine any public IPv4 address. Cannot proceed." >&2
            return 1
        fi
        return 0
    }

    # Login to Azure
    perform_az_login() {
        if [[ "$skip_login" == true ]]; then
            echo "🔑 Skipping Azure login as requested."
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
            az account set --subscription "$SUBSCRIPTION_ID"
        fi
        return 0
    }

    # --- Main Execution Flow ---
    {
        local -a desired_ips_array
        local -A desired_rules_map 
        local -A existing_rules_map

        # 1. Get current and additional IPs
        get_public_ips || return 1

        # --- TRACE POINT 3: KEYS OF THE detected_ips MAP ---
        echo "[TRACE 3 KEYS IN detected_ips MAP]"
        for key in "${(@k)detected_ips}"; do
            printf "  -> MAP KEY: %q\n" "$key"
        done

        desired_ips_array=("${(k)detected_ips[@]}")
        
        # --- TRACE POINT 4: ITEMS IN desired_ips_array ---
        echo "[TRACE 4 ITEMS IN desired_ips_array]"
        for item in "${desired_ips_array[@]}"; do
            printf "  -> ARRAY ITEM: %q\n" "$item"
        done
        
        for ip in "${additional_ips[@]}"; do
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                desired_ips_array+=("$ip")
            fi
        done
        desired_ips_array=("${(u)desired_ips_array[@]}")

        # Generate rule names
        for ip in "${desired_ips_array[@]}"; do
            local rule_name="Eugene_WFH_$(date +'%Y-%m-%d')_$(echo "$ip" | tr '.' '-')"
            desired_rules_map["$ip"]="$rule_name"
        done

        # 2. Authenticate
        perform_az_login || return 1

        # 3. Get existing rules
        echo "🔍 Fetching existing 'Eugene_WFH' rules from Azure..."
        local existing_rules_json
        existing_rules_json=$(az sql server firewall-rule list -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" --query "[?starts_with(name, 'Eugene_WFH')].{name:name, ip:startIpAddress}" -o json 2>/dev/null)
        if [[ -n "$existing_rules_json" ]]; then
            echo "$existing_rules_json" | jq -c '.[]' | while IFS= read -r rule_entry; do
                local name=$(echo "$rule_entry" | jq -r '.name')
                local ip=$(echo "$rule_entry" | jq -r '.ip')
                if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    existing_rules_map["$ip"]="$name"
                fi
            done
        fi
        
        # 4. Determine diff
        local -a ips_to_add
        local -a ips_to_delete
        for ip in "${(@k)desired_rules_map}"; do
            if [[ -z "${existing_rules_map[$ip]}" ]]; then ips_to_add+=("$ip"); fi
        done
        for ip in "${(@k)existing_rules_map}"; do
            if [[ -z "${desired_rules_map[$ip]}" ]]; then ips_to_delete+=("$ip"); fi
        done

        # 5. Execute changes
        if (( ${#ips_to_add[@]} > 0 )); then
            echo "✨ Creating new rules for missing IPs..."
            for ip in "${ips_to_add[@]}"; do
                # --- TRACE POINT 5: FINAL IP BEFORE AZ COMMAND ---
                printf "[TRACE 5 FINAL IP TO ADD] %q\n" "$ip"
                local rule_name="${desired_rules_map[$ip]}"
                echo "  -> Adding rule: '$rule_name' for IP $ip"
                az sql server firewall-rule create -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" -n "$rule_name" --start-ip-address "$ip" --end-ip-address "$ip" --only-show-errors > /dev/null
            done
        else
            echo "🎉 No new rules to create."
        fi
        if (( ${#ips_to_delete[@]} > 0 )); then
            echo "🧹 Deleting old rules for stale IPs..."
            for ip in "${ips_to_delete[@]}"; do
                local rule_name="${existing_rules_map[$ip]}"
                echo "  -> Deleting rule: '$rule_name' for IP $ip"
                az sql server firewall-rule delete -g "$RESOURCE_GROUP_NAME" -s "$SERVER_NAME" -n "$rule_name" --only-show-errors > /dev/null
            done
        else
            echo "🧹 No stale rules to delete."
        fi
        echo "✅ Operation completed successfully."
    } || {
        echo "❌ An error occurred during execution." >&2
        return 1
    }
}