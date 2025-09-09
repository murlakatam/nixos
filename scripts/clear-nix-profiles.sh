#!/usr/bin/env bash

PROFILES_DIR="/nix/var/nix/profiles"
# Define how many of the latest generations to keep 
KEEP_COUNT=5

[[ "$1" == "remove" ]] && [[ $EUID -ne 0 ]] && echo "Error: Root required" && exit 1

# Get all profiles, sorted by version number (oldest to newest)
ALL_PROFILES=($(find "$PROFILES_DIR" -maxdepth 1 -name "system-*-link" -exec basename {} \; | sort -V))
CURRENT_PROFILE=$(basename "$(readlink "$PROFILES_DIR/system")")

if [[ "$1" == "remove" ]]; then
    # --- MODIFIED LOGIC START ---

    # Create a set (associative array) of the profiles we want to keep for fast lookups
    declare -A PROFILES_TO_KEEP
    
    # Always keep the currently active profile
    PROFILES_TO_KEEP["$CURRENT_PROFILE"]=1
    
    # Determine the last 5 profiles from the sorted list
    count=${#ALL_PROFILES[@]}
    start_index=$((count - KEEP_COUNT))
    if (( start_index < 0 )); then
        start_index=0
    fi
    LATEST_PROFILES=("${ALL_PROFILES[@]:start_index}")
    
    # Add the latest profiles to our keep list
    for profile in "${LATEST_PROFILES[@]}"; do
        PROFILES_TO_KEEP["$profile"]=1
    done

    removed=0
    echo "Keeping the current profile and the ${#LATEST_PROFILES[@]} latest profiles..."
    for profile in "${ALL_PROFILES[@]}"; do
        # If the profile is NOT in our set of profiles to keep, remove it
        if [[ -z "${PROFILES_TO_KEEP[$profile]}" ]]; then
            sudo rm "$PROFILES_DIR/$profile" 2>/dev/null && ((removed++))
        fi
    done
    # --- MODIFIED LOGIC END ---

    echo "Removed $removed old profiles"
else
    # Default info mode remains the same
    echo "Current: $CURRENT_PROFILE"
    echo "Total: ${#ALL_PROFILES[@]} profiles"
fi