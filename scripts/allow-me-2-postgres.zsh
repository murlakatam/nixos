allow-me-2-postgres() {
    local RESOURCE_GROUP_NAME="MATA-ERS-DEVTEST-PSQL-DATABASES"
    local SERVER_NAME="mataersdevtestfpsqlserver"
    
    # Get public IP address
    get_public_ip() {
        echo "Detecting current public IP address..."
        local public_ip=$(curl -s https://api.ipify.org)
        echo "Detected public IP: $public_ip"
        echo "$public_ip"
    }
    
    # Get full subnet range from IP address
    get_full_subnet_range() {
        local ip_address=$1
        
        echo "Processing IP address: $ip_address"
        
        # Validate IP address format
        if [[ ! $ip_address =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
            echo "Invalid IPv4 address format. Please provide a valid IPv4 address." >&2
            return 1
        fi
        
        # Manual parsing of IP address to avoid zsh-specific syntax issues
        local first=$(echo "$ip_address" | cut -d. -f1)
        local second=$(echo "$ip_address" | cut -d. -f2)
        local third=$(echo "$ip_address" | cut -d. -f3)
        
        local first_three_octets="${first}.${second}.${third}"
        
        # Create the full subnet range
        local start_ip="${first_three_octets}.0"
        local end_ip="${first_three_octets}.255"
        local subnet="${first_three_octets}.0/24"
        
        echo "Calculated subnet: $start_ip to $end_ip"
        
        # Return the values directly
        echo "start_ip=$start_ip"
        echo "end_ip=$end_ip"
        echo "subnet=$subnet"
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
        echo "Using parameters:"
        echo "  Resource Group: $resource_group"
        echo "  Server Name: $server_name"
        echo "  Start IP: $start_ip"
        echo "  End IP: $end_ip"
        echo "  Subnet: $subnet"
        
        # Check if the rule already exists and delete it if it does
        if az postgres flexible-server firewall-rule show --resource-group "$resource_group" --name "$server_name" --rule-name "Eugene_WFH" &>/dev/null; then
            echo "Existing 'Eugene_WFH' rule found. Deleting it first..."
            az postgres flexible-server firewall-rule delete --resource-group "$resource_group" --name "$server_name" --rule-name "Eugene_WFH" --yes
        fi
        
        # Create new firewall rule with full subnet range
        echo "Creating firewall rule with start IP: $start_ip and end IP: $end_ip"
        
        # Ensure we have valid IPs before proceeding
        if [[ -z "$start_ip" || -z "$end_ip" ]]; then
            echo "Error: Start IP or End IP is empty. Cannot proceed." >&2
            return 1
        fi
        
        az postgres flexible-server firewall-rule create \
          --resource-group "$resource_group" \
          --name "$server_name" \
          --rule-name "Eugene_WFH" \
          --start-ip-address "$start_ip" \
          --end-ip-address "$end_ip"
        
        if [[ $? -ne 0 ]]; then
            echo "Failed to update PostgreSQL flexible server firewall rules." >&2
            return 1
        fi
        
        echo "Successfully updated PostgreSQL flexible server firewall rules with subnet range: $subnet"
    }
    
    # Main function execution flow
    {
        local public_ip=$(get_public_ip)
        echo "Working with public IP: $public_ip"
        
        # Get subnet information
        local subnet_info=$(get_full_subnet_range "$public_ip")
        echo "Subnet info: $subnet_info"
        
        # Parse the returned values directly
        local start_ip=$(echo "$subnet_info" | grep "start_ip=" | cut -d= -f2)
        local end_ip=$(echo "$subnet_info" | grep "end_ip=" | cut -d= -f2)
        local subnet=$(echo "$subnet_info" | grep "subnet=" | cut -d= -f2)
        
        echo "Parsed values:"
        echo "  Start IP: $start_ip"
        echo "  End IP: $end_ip"
        echo "  Subnet: $subnet"
        
        perform_az_login
        update_postgres_networking "$RESOURCE_GROUP_NAME" "$SERVER_NAME" "$start_ip" "$end_ip" "$subnet"
        
        echo "Operation completed successfully."
    } || {
        echo "An error occurred: $?" >&2
        return 1
    }
}
