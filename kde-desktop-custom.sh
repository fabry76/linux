#!/bin/bash
# Run at KDE login: creates a trash bin, clock, and wallpaper on the desktop
# if they are not already present (idempotently).

QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || command -v qdbus-qt5)" || exit 0
WALL="$HOME/Pictures/wall.jpg"

# Wait for plasmashell to be ready (max. 30 seconds)
for _ in $(seq 1 30); do
	"$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && break
	sleep 1
done

"$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
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
	d.writeConfig('Image', 'file://$WALL');
	d.reloadConfig();
});
"
