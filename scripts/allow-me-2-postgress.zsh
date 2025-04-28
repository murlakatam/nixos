
#!/run/current-system/sw/bin/zsh

allow-me-2-postgres() {
    local RESOURCE_GROUP_NAME="MATA-ERS-DEVTEST-PSQL-DATABASES"
    local SERVER_NAME="mataersdevtestfpsqlserver"
    
    # Get public IP address
    get_public_ip() {
        echo "Detecting current public IP address..."
        local public_ip=$(curl -s https://api.ipify.org)
        echo "Detected public IP: $public_ip"
        echo $public_ip
    }
    
    # Get full subnet range from IP address
    get_full_subnet_range() {
        local ip_address=$1
        
        # Validate IP address format
        if [[ ! $ip_address =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
            echo "Invalid IPv4 address format. Please provide a valid IPv4 address." >&2
            return 1
        fi
        
        # Split the IP address into octets and keep only the first three
        local octets=(${(s:.:)ip_address})
        local first_three_octets="${octets[1]}.${octets[2]}.${octets[3]}"
        
        # Create the full subnet range
        local start_ip="${first_three_octets}.0"
        local end_ip="${first_three_octets}.255"
        local subnet="${first_three_octets}.0/24"
        
        # Return values as a string that can be parsed
        echo "original_ip=$ip_address start_ip=$start_ip end_ip=$end_ip subnet=$subnet"
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
    }
    
    # Update PostgreSQL networking rules
    update_postgres_networking() {
        local resource_group=$1
        local server_name=$2
        local start_ip=$3
        local end_ip=$4
        local subnet=$5
        
        echo "Updating PostgreSQL flexible server firewall rules..."
        
        # Check if the rule already exists and delete it if it does
        if az postgres flexible-server firewall-rule show --resource-group $resource_group --name $server_name --rule-name "Eugene_WFH" &>/dev/null; then
            echo "Existing 'Eugene_WFH' rule found. Deleting it first..."
            az postgres flexible-server firewall-rule delete --resource-group $resource_group --name $server_name --rule-name "Eugene_WFH" --yes
        fi
        
        # Create new firewall rule with full subnet range
        az postgres flexible-server firewall-rule create --resource-group $resource_group --name $server_name --rule-name "Eugene_WFH" --start-ip-address $start_ip --end-ip-address $end_ip
        
        if [[ $? -ne 0 ]]; then
            echo "Failed to update PostgreSQL flexible server firewall rules." >&2
            return 1
        fi
        
        echo "Successfully updated PostgreSQL flexible server firewall rules with subnet range: $subnet"
    }
    
    # Main function execution flow
    {
        local public_ip=$(get_public_ip)
        local ip_range_str=$(get_full_subnet_range $public_ip)
        
        # Parse the returned string into variables
        local original_ip start_ip end_ip subnet
        eval $ip_range_str
        
        echo "Using full subnet range: $start_ip to $end_ip ($subnet)"
        
        perform_az_login
        update_postgres_networking $RESOURCE_GROUP_NAME $SERVER_NAME $start_ip $end_ip $subnet
        
        echo "Operation completed successfully."
    } || {
        echo "An error occurred: $?" >&2
    }
}
