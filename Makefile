# ==============================================================================
#           NixOS & Home-Manager Configuration Makefile (Git-Integrated)
# ==============================================================================
#
# This Makefile automates the management of a NixOS and Home Manager
# configuration that is version-controlled with Git.
#
# It combines standard Nix build commands with a git-centric workflow inspired
# by the provided bash script. The core idea is to treat every successful
# system change as a commit.
#
# --- NEW WORKFLOW for 'system' and 'home' targets ---
# 1. Opens your configuration directory in your editor for final review.
# 2. Checks for any uncommitted changes in your Nix files. Exits if none.
# 3. Automatically formats all Nix code using 'alejandra'.
# 4. Shows you a summary of the changes to be applied.
# 5. Prompts for confirmation before proceeding with the build.
# 6. Runs the appropriate NixOS or Home Manager build command.
# 7. On success, automatically commits the changes with the new system
#    generation details as the commit message.
# 8. Pushes the new commit to your git remote.
# 9. Sends a desktop notification upon successful completion.
#
# --- NEW USAGE ---
#
# - `make system`:         Applies the system config with the new git workflow.
# - `make home`:           Applies the home-manager config with the new git workflow.
# - `make all`:            Runs both 'home' and 'system' targets sequentially.
# - `make update`:         Updates flake inputs and applies the changes via the
#                          'system' target, all in one step.
# - `make system REPAIR=true`:  Run a system build in repair mode.
# - `make update RECREATE=true`: Force a flake lock file recreation and apply.
#
# ==============================================================================

# --- User Configuration ---
# This section contains variables you should customize for your environment.

# Set the absolute path to your Nix configuration directory (e.g., your dotfiles repo).
# We use $(HOME) to ensure it's an absolute path.
CONFIG_DIR := $(HOME)/dotfiles/nixos

# Set the default editor to open for reviewing changes.
# It will wait for the editor to be closed before continuing (`--wait`).
EDITOR := code --wait

# Define the user and hostname using shell commands for portability.
USERNAME := $(shell whoami)
HOSTNAME := $(shell hostname)

# Construct the Flake URIs from the variables above. This makes the file
# reusable on different machines without hardcoding paths.
# The '.' refers to the flake file within the CONFIG_DIR.
FLAKE_URI_SYSTEM := .#$(HOSTNAME)
FLAKE_URI_HOME := .#$(USERNAME)@$(HOSTNAME)


# --- Makefile Internals ---
# These are the core routines and targets.

# Use .PHONY to declare targets that are not actual files.
# This prevents conflicts and can improve performance.
.PHONY: all home system update clean sysboot bootloader seed-iso burn-iso test-iso seed-debug deploy-% edit-shared-secrets-host help

# The default target when you just run `make`.
all: home system

# --- Core Build & Commit Routine ---
# This version assumes the user has already reviewed and saved their files.
define REBUILD_ROUTINE
	echo "--- 1. Checking for Changes ---" && \
	if [ -z "$(UPDATE)$(RECREATE)" ] && git diff --quiet '*.nix' '*.lock' '*.zsh' '*.json' '*.sh'; then \
		echo "✅ No changes detected in configuration files. Nothing to do."; \
		exit 0; \
	fi && \
	\
	echo "--- 2. Formatting and Confirming ---" && \
	echo "✨ Auto-formatting Nix files with Alejandra..." && \
	if ! alejandra . &>/dev/null; then \
		alejandra . || (echo "❌ Formatting failed!" && exit 1); \
	fi && \
	echo "🔍 Git changes to be applied:" && \
	git diff -U0 --color=always '*.nix' && \
	echo "" && \
	read -p "🤔 Proceed with build? (y/N) " -n 1 -r; \
	echo; \
	if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Aborted by user."; \
		exit 1; \
	fi && \
	\
	echo "--- 3. Updating and Building ---" && \
	if [ "$(RECREATE)" = "true" ]; then \
		echo " Clobbering lock file and updating flake inputs..."; \
		sudo nix flake update --recreate-lock-file; \
	elif [ "$(UPDATE)" = "true" ]; then \
		echo " Updating flake inputs..."; \
		sudo nix flake update; \
	fi && \
	echo "🚀 Starting build..." && \
	sudo $(1) 2> >(tee /tmp/nixos-build-errors.log >&2) && \
	\
	echo "--- 4. Committing, Pushing, and Notifying ---" && \
	echo "✅ Build successful! Committing changes..." && \
	current_generation=$$(nixos-rebuild list-generations | grep -w 'current' | sed 's/\s\+/ /g') && \
	git commit -am "$$current_generation" && \
	echo " Pushing changes to remote..." && \
	git push && \
	notify-send -e "NixOS Rebuilt OK!" "Committed: $$current_generation" --icon=software-update-available && \
	echo "🎉 All done!"
endef

# --- Primary Targets ---

# The new `update` target. It sets the UPDATE variable and then depends on `system`.
# This ensures the flake inputs are updated before the system is rebuilt.
update:
	$(MAKE) system UPDATE=true RECREATE=$(RECREATE)

# The new `home` target.
# It calls the REBUILD_ROUTINE with the correct `home-manager` command.
home:
	@echo "--- Starting Home Manager Build ---"
	$(call REBUILD_ROUTINE, home-manager switch --flake $(FLAKE_URI_HOME))

# The new `system` target.
# It checks for the REPAIR variable and constructs the correct `nixos-rebuild`
# command before passing it to the REBUILD_ROUTINE.
system:
	@echo "--- Starting NixOS System Build ---"
	@# Conditional logic to handle the `REPAIR=true` case.
	$(if $(REPAIR), \
		$(call REBUILD_ROUTINE, nixos-rebuild switch --flake $(FLAKE_URI_SYSTEM) --show-trace --repair), \
		$(call REBUILD_ROUTINE, nixos-rebuild switch --flake $(FLAKE_URI_SYSTEM) --show-trace) \
	)

# --- Unchanged Utility Targets ---
# These targets from the original Makefile are useful and are kept as-is.
# They do not use the new git-integrated workflow.

sysboot:
	@echo "Switching NixOS configuration (boot only)..."
	sudo nixos-rebuild boot --flake $(FLAKE_URI_SYSTEM)

bootloader:
	@echo "Switching NixOS configuration (boot only) and installing bootloader..."
	sudo nixos-rebuild boot --install-bootloader --flake $(FLAKE_URI_SYSTEM)

clean:
	@echo "Cleaning old generations..."
	sudo ./utils/clear-nix-profiles.sh remove
	nix-collect-garbage --delete-old
	nix-store --gc --print-roots | egrep -v "^(/nix/var|/run/\w+-system|\{memory|/proc)"

seed-iso:
	@echo "Generating Seed ISO..."
	export SSH_PRIVATE_HOST=$$(sops -d --extract '["ssh_private_seed"]' ./shared-secrets.yaml) && \
	export SSH_PUBLIC_HOST=$$(sops -d --extract '["ssh_public_seed"]' ./shared-secrets.yaml) && \
	nix build --impure .#nixosConfigurations.seed.config.system.build.isoImage

burn-iso:
	@echo "Burning Seed ISO..."
	$(eval OUTPUT_DEVICE := $(shell udevadm info --name=/dev/sda | grep -q "ID_VENDOR=SanDisk" && udevadm info --name=/dev/sda | grep -q "ID_MODEL=Ultra" && echo "/dev/sda" || echo ""))
	caligula burn result/iso/seed.iso -z none -s skip -f --root always $(if $(OUTPUT_DEVICE),-o $(OUTPUT_DEVICE))

test-iso:
	@echo "Starting virtual machine"
	sudo virt-install \
	--name nixos-debug --os-variant nixos-unstable \
	--cdrom result/iso/seed.iso --boot cdrom \
	--memory 8192 --vcpus 12 --disk none \
	--graphics spice,listen=0.0.0.0 --video virtio --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 \
	--noautoconsole --sound ich9 --network bridge=br0,model=virtio,mac=00:11:22:33:44:55 && \
	sudo -E virt-viewer --zoom=200 --wait nixos-debug && \
	sudo virsh destroy nixos-debug && \
	sudo virsh undefine nixos-debug

seed-debug:
	@echo "Generating Seed ISO..."
	export SSH_PRIVATE_HOST=$$(sops -d --extract '["ssh_private_seed"]' ./shared-secrets.yaml) && \
	export SSH_PUBLIC_HOST=$$(sops -d --extract '["ssh_public_seed"]' ./shared-secrets.yaml) && \
	nix build --impure .#nixosConfigurations.seed.config.system.build.toplevel

deploy-%:
	@echo "Deploying new configuration to host '$*'..."
	./utils/deploy-host.sh $* $(USERNAME)

edit-shared-secrets-host:
	export SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) && \
	sops shared-secrets.yaml

help:
	@echo "Available targets:"
	@echo ""
	@echo "  --- Git-Integrated Workflow ---"
	@echo "  all           - Run both 'home' and 'system' build routines (default)."
	@echo "  system        - Build and switch NixOS configuration with git workflow."
	@echo "  home          - Build and switch home-manager configuration with git workflow."
	@echo "  update        - Update flake inputs, then run the 'system' build routine."
	@echo ""
	@echo "  --- Target Options (Variables) ---"
	@echo "  make update RECREATE=true - Force recreation of the flake.lock file."
	@echo "  make system REPAIR=true   - Run nixos-rebuild in '--repair' mode."
	@echo ""
	@echo "  --- Utility Targets ---"
	@echo "  clean         - Remove old garbage-collected generations."
	@echo "  sysboot       - Create a new boot entry without making it default."
	@echo "  deploy-%      - Deploy configuration to a remote host (e.g., 'make deploy-server1')."
	@echo "  help          - Show this help message."