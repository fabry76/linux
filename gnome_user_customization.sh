#!/bin/bash
# GNOME user customization

set -uo pipefail

if [ "$EUID" -eq 0 ]; then
	echo "Do not run as root"
	exit 1
fi

###############################################
# Fedora: extras
###############################################
if [ "${DISTRO:-}" = "fedora" ]; then
	ICON_DIR="$HOME/.local/share/icons"

	# Tela icon theme installation
	if [ -d "$ICON_DIR/Tela" ]; then
		echo "Tela icon theme already installed, skipping."
	else
		echo "Installing Tela icon theme..."
		TMP_DIR="$(mktemp -d)"

		mkdir -p "$ICON_DIR"
		if curl -fsSL -o "$TMP_DIR/tela.zip" \
				https://github.com/vinceliuice/Tela-icon-theme/archive/refs/heads/master.zip &&
		   unzip -q "$TMP_DIR/tela.zip" -d "$TMP_DIR" &&
		   "$TMP_DIR"/Tela-icon-theme-master/install.sh -d "$ICON_DIR"; then
			echo "Tela icon theme installed."
		else
			echo "Tela icon theme installation failed."
		fi

		rm -rf "$TMP_DIR"
	fi
fi
