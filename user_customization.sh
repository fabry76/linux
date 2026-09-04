#!/bin/bash
set -euo pipefail

###############################################
# User validation
###############################################
if [ "$EUID" -eq 0 ]; then
	echo "Do not run as root"
	exit 1
fi

###############################################
# Desktop selection
###############################################
DESKTOP_CHOICE="${DESKTOP_CHOICE:-${desktop_choice:-}}"

case "$DESKTOP_CHOICE" in
	1)
		echo "KDE desktop selected."
		;;
	2)
		echo "GNOME desktop selected."
		;;
	"")
		echo "No desktop selected; skipping desktop-specific configuration."
		;;
	*)
		echo "Invalid desktop choice"
		exit 1
		;;
esac

###############################################
# Write if changed
###############################################
write_if_changed() {
	local file="$1"
	local content="$2"

	if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
		return 0
	fi

	printf "%s" "$content" > "$file"
}

###############################################
# Install file if changed
###############################################
install_if_changed() {
	local src="$1"
	local dst="$2"
	local mode="${3:-644}"

	if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
		return 0
	fi

	install -D -m "$mode" "$src" "$dst"
}

###############################################
# Required paths and folders
###############################################
xdg-user-dirs-update

rm -rf "$HOME/Videos"
ln -sfn "$HOME/Fastgate/Media/" "$HOME/Videos"

DESKTOP_DIR="$(xdg-user-dir DESKTOP)"

mkdir -p \
	"$HOME/.config" \
	"$HOME/.config/pipewire/pipewire.conf.d"

###############################################
# GNOME .desktop files
###############################################
if [ "$DESKTOP_CHOICE" = "2" ]; then
	SRC_BRV="/usr/share/applications/brave-origin.desktop"
	DST_BRV="$HOME/.local/share/applications/brave-origin.desktop"

	if [[ -f "$SRC_BRV" && ! -f "$DST_BRV" ]]; then
		mkdir -p "$(dirname "$DST_BRV")"
		cp "$SRC_BRV" "$DST_BRV"
		sed -i 's/^StartupNotify=true$/StartupNotify=false/' "$DST_BRV"
	elif [[ ! -f "$SRC_BRV" ]]; then
		echo "Brave not installed, skipping shortcut"
	else
		echo "Brave shortcut already exists, skipping"
	fi

	SRC_CHR="/usr/share/applications/google-chrome.desktop"
	DST_CHR="$HOME/.local/share/applications/google-chrome.desktop"

	if [[ -f "$SRC_CHR" && ! -f "$DST_CHR" ]]; then
		mkdir -p "$(dirname "$DST_CHR")"
		cp "$SRC_CHR" "$DST_CHR"
		sed -i 's/^StartupNotify=true$/StartupNotify=false/' "$DST_CHR"
	elif [[ ! -f "$SRC_CHR" ]]; then
		echo "Chrome not installed, skipping shortcut"
	else
		echo "Chrome shortcut already exists, skipping"
	fi
fi

###############################################
# KDE configuration
###############################################
if [ "$DESKTOP_CHOICE" = "1" ]; then
	mkdir -p \
		"$HOME/.config/mpv" \
		"$HOME/.local/share/konsole"

	KONSOLERC="$HOME/.config/konsolerc"
	KONSOLERC_CONTENT=$(cat <<EOF
[Desktop Entry]
DefaultProfile=ff.profile
Version=1.0

[General]
ConfigVersion=1
DefaultProfile=ff.profile

[UiSettings]
ColorScheme=
EOF
	)

	write_if_changed "$KONSOLERC" "$KONSOLERC_CONTENT"

	[ -f "$HOME/Git/linux/etc/ff.profile" ] && \
	install_if_changed \
		"$HOME/Git/linux/etc/ff.profile" \
		"$HOME/.local/share/konsole/ff.profile"

	[ -f "$HOME/Git/linux/etc/plasma-localerc" ] && \
	install_if_changed \
		"$HOME/Git/linux/etc/plasma-localerc" \
		"$HOME/.config/plasma-localerc"

	[ -f "$HOME/Git/linux/etc/mpv.conf" ] && \
	install_if_changed \
		"$HOME/Git/linux/etc/mpv.conf" \
		"$HOME/.config/mpv/mpv.conf"

	[ -f "$HOME/Git/linux/etc/computer.desktop" ] && \
	install -D \
  		"$HOME/Git/linux/etc/computer.desktop" \
  		"$DESKTOP_DIR/computer.desktop"
fi

###############################################
# Starship
###############################################
grep -qF 'eval "$(starship init bash)"' "$HOME/.bashrc" || \
	echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"

[ -f "$HOME/Git/linux/etc/starship.toml" ] && \
install_if_changed \
	"$HOME/Git/linux/etc/starship.toml" \
	"$HOME/.config/starship.toml"

###############################################
# PipeWire
###############################################
[ -f "$HOME/Git/linux/etc/l16g2-speaker-profile.conf" ] && \
install_if_changed \
	"$HOME/Git/linux/etc/l16g2-speaker-profile.conf" \
	"$HOME/.config/pipewire/pipewire.conf.d/l16g2-speaker-profile.conf"

###############################################
# Git setup
###############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/git.sh" ] && [ -d "$HOME/Fastgate/Varie/github" ]; then
	echo "Running Git setup..."
	bash "$SCRIPT_DIR/git.sh"
fi

###############################################
# Done
###############################################
echo "User customization completed."