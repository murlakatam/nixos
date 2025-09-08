# A robust function to rebuild our NixOS system
  rebuild-new() {
    # The directory where your SOURCE Makefile lives
    local configDir="$HOME/dotfiles/nixos"

    echo "Entering Nix configuration directory..."
    pushd "$configDir" >/dev/null

    # Open the editor and wait for it to be closed before proceeding.
    # This relies on the $EDITOR environment variable being set correctly.
    echo " opening editor for review (close editor to continue)..."
    $EDITOR .

    echo " editor closed. Proceeding with the build..."

    # Run 'make' and pass along all arguments you gave the function
    command make "$@"

    # Return to the directory you were in before
    popd >/dev/null
  }