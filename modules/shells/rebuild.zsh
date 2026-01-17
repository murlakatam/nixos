# A robust function to rebuild our NixOS system. Rebuild everthing with Makefile
  rebuild() {
    local configDir="@dotfilesPath@"

    echo "Entering Nix configuration directory $configDir..."
    pushd "$configDir" >/dev/null

    # Open the editor and wait for it to be closed before proceeding. comment
    # This relies on the $EDITOR environment variable being set correctly to a command
    # that waits, such as "code --wait".
    echo " -- opening editor for review (close editor to continue)..."
    # The command here ensures the system waits for the editor to close.
    command $EDITOR .

    echo " -- editor closed. Proceeding with the build..."

    # Check if any arguments were passed to the function.
    # If not, default to the "system" target.
    local target=${1:-system}
    # Use shift to remove the first argument if it exists, so the rest ($@) are variables.
    if [[ $# -gt 0 ]]; then
      shift
    fi

    # Run 'make' with the determined target and pass along any remaining arguments.
    command make "$target" "$@"

    # Return to the directory you were in before
    popd >/dev/null
  }