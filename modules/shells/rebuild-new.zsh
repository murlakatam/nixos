# A robust function to rebuild our NixOS system
  rebuild-new() {
    # The directory where your SOURCE Makefile lives
    local configDir="$HOME/dotfiles/nixos"

    # Use pushd to change directory and save our location
    pushd "$configDir" >/dev/null

    # Run 'make' and pass along all arguments you gave the function (e.g., "system", "update")
    # The 'command' prefix ensures we don't accidentally call an alias named 'make'
    command make "$@"

    # Use popd to return to the directory you were in before
    popd >/dev/null
  }