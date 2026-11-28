#!/bin/bash
set -uo pipefail

if [ "$EUID" -eq 0 ]; then
	echo "Do not run as root"
	exit 1
fi

###############################################
# Helpers
###############################################
write_if_changed() {
	local file="$1"
	local content="$2"

	if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
		return 0
	fi

	printf "%s" "$content" > "$file"
}

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
# Setup phase
###############################################
config_root="$HOME/Git/linux/etc/kde"
desktop_dir="$(xdg-user-dir DESKTOP)"

# KDE config files
while IFS= read -r -d '' src; do
	install_if_changed "$src" "$HOME/${src#"$config_root"/}"
done < <(find "$config_root/.config" "$config_root/.local" -type f -print0 2>/dev/null)

# Desktop icon
if [ -f "$config_root/computer.desktop" ]; then
	install_if_changed \
		"$config_root/computer.desktop" \
		"$desktop_dir/computer.desktop" \
		755
fi

true