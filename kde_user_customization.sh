#!/bin/bash
# KDE user customization.
#
#   kde_user_customization.sh           setup phase (called by user_customization.sh):
#                                       installs KDE config files and the desktop icon,
#                                       installs itself to ~/.local/bin and creates the
#                                       autostart entry for the login phase
#   kde_user_customization.sh --login   login phase (run by autostart): creates a trash
#                                       bin, clock, and wallpaper on the desktop if not
#                                       already present (idempotently), then removes
#                                       the autostart entry

set -uo pipefail

if [ "$EUID" -eq 0 ]; then
	echo "Do not run as root"
	exit 1
fi

AUTOSTART_FILE="$HOME/.config/autostart/kde-user-customization.desktop"
INSTALLED_SCRIPT="$HOME/.local/bin/kde_user_customization.sh"

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
setup_phase() {
	local config_root="$HOME/Git/linux/etc/kde"
	local desktop_dir
	desktop_dir="$(xdg-user-dir DESKTOP)"

	# KDE config files
	find "$config_root/.config" \
	     "$config_root/.local" \
	     -type f 2>/dev/null |
	while read -r src; do
		install_if_changed "$src" "$HOME/${src#"$config_root"/}"
	done

	# Desktop icon
	[ -f "$config_root/computer.desktop" ] && \
		install_if_changed \
			"$config_root/computer.desktop" \
			"$desktop_dir/computer.desktop" \
			755

	# Install this script and register it for the next KDE login
	install_if_changed "$(readlink -f "$0")" "$INSTALLED_SCRIPT" 755

	mkdir -p "$HOME/.config/autostart"
	write_if_changed "$AUTOSTART_FILE" \
"[Desktop Entry]
Type=Application
Name=KDE user customization
Exec=$INSTALLED_SCRIPT --login
X-KDE-autostart-after=panel
"
}

###############################################
# Login phase
###############################################
login_phase() {
	local qdbus wall="$HOME/Pictures/wall.jpg"

	qdbus="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || command -v qdbus-qt5)" || exit 0

	# Wait for plasmashell to be ready (max. 30 seconds)
	for _ in $(seq 1 30); do
		"$qdbus" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
		sleep 1
	done

	"$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
desktops().forEach(function (d) {
	if (d.screen != 0) return;
	if (d.widgets('org.kde.plasma.trash').length > 0 ||
	    d.widgets('org.kde.plasma.digitalclock').length > 0) return;

	d.addWidget('org.kde.plasma.trash', 0, 112, 112, 96);

	var w = d.addWidget('org.kde.plasma.digitalclock', 1568, 32, 352, 176);
	w.currentConfigGroup = ['Appearance'];
	w.writeConfig('autoFontAndSize', false);
	w.writeConfig('dateFormat', 'longDate');
	w.writeConfig('fontFamily', 'Liberation Serif');
	w.writeConfig('fontSize', 14);
	w.writeConfig('fontStyleName', 'Italic');
	w.writeConfig('fontWeight', 400);
	w.writeConfig('italicText', true);
	w.writeConfig('use24hFormat', 2);
	w.reloadConfig();

	d.wallpaperPlugin = 'org.kde.image';
	d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
	d.writeConfig('Image', 'file://$wall');
	d.reloadConfig();
});
"

	rm -f "$AUTOSTART_FILE"
}

###############################################
# Main
###############################################
case "${1:-}" in
	--login) login_phase ;;
	"")      setup_phase ;;
	*)       echo "Usage: $0 [--login]"; exit 1 ;;
esac
