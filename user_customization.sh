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
	install_if_changed \
		"$HOME/Git/linux/etc/computer.desktop" \
		"$DESKTOP_DIR/computer.desktop" \
	755
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
REPO_PATH="$HOME/Git/linux"
SOURCE_KEY="$HOME/Fastgate/Varie/github/id_ed25519"
DEST_KEY="$HOME/.ssh/id_ed25519"
REMOTE_URL="git@github.com:fabry76/linux.git"

# Fastgate check
if [ ! -f "$SOURCE_KEY" ]; then
    echo
    echo "SSH key not found:"
    echo "$SOURCE_KEY"
    echo
    echo "Fastgate share is probably not mounted."
    exit 1
fi

# SSH directory
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# SSH config
SSH_CONFIG_CONTENT='Host github.com
HostName github.com
User git
IdentityFile ~/.ssh/id_ed25519
IdentitiesOnly yes'

write_if_changed "$HOME/.ssh/config" "$SSH_CONFIG_CONTENT"
chmod 600 "$HOME/.ssh/config"

# Known hosts
touch "$HOME/.ssh/known_hosts"
chmod 644 "$HOME/.ssh/known_hosts"

if ! ssh-keygen -F github.com >/dev/null; then
    ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    echo "GitHub host key added"
fi

# SSH KEY
if [ ! -f "$DEST_KEY" ] || ! cmp -s "$SOURCE_KEY" "$DEST_KEY"; then
    cp "$SOURCE_KEY" "$DEST_KEY"
    chmod 600 "$DEST_KEY"
    echo "SSH key installed/updated"
fi

# Repository (auto-clone if missing)
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Repository not found, cloning..."

    mkdir -p "$(dirname "$REPO_PATH")"
    git clone "$REMOTE_URL" "$REPO_PATH"
fi

cd "$REPO_PATH"
echo "Inside repository: $(pwd)"

# Git config
git config --global user.name "fabry76"
git config --global user.email "fabrizio.fabiani@gmail.com"

# Remote setup
if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi

# Test SSH (non interactive)
echo "Testing SSH connection..."
ssh -o BatchMode=yes -T git@github.com || true

echo "Git setup completed successfully"

###############################################
# Done
###############################################
echo "User customization completed."