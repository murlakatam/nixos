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
            current_