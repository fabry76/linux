#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"

###############################################
# KDE Plasma base
###############################################
dnf install -y \
    plasma-desktop \
    plasma-login-manager \
    kwin \
    plasma-nm \
    plasma-pa \
    kscreen \
    konsole \
    dolphin \
    ark \
    spectacle \
    kwrite \
    plasma-systemmonitor \
    isoimagewriter \
    kolourpaint \
    gwenview \
    okular \
    kcolorchooser \
    krecorder \
    mpv \
    skanpage \
    kclock \
    kamoso \
    plasma-print-manager \
    filelight \
    kcharselect \
    kde-partitionmanager \
    kwalletmanager5 \
    pam-kwallet \
    bluedevil \
    kde-gtk-config \
    breeze-gtk \
    kinfocenter \
    kdegraphics-thumbnailers \
    qalculate-qt

systemctl enable plasmalogin
systemctl set-default graphical.target

###############################################
# KDE Flatpak base setup
###############################################
dnf install -y \
    plasma-discover-flatpak \
    xdg-desktop-portal-kde

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# Variables
###############################################
BROWSER_APP=""

FLATPAK_APPS=(
    org.gtk.Gtk3theme.Breeze
    org.qbittorrent.qBittorrent
)

###############################################
# Browser selection
###############################################
case "$FLATPAK_BROWSER" in
    1)
        BROWSER_APP="io.gitlab.librewolf-community"
        FLATPAK_APPS+=(io.gitlab.librewolf-community)
        ;;
    2)
        BROWSER_APP="com.brave.Browser"
        FLATPAK_APPS+=(com.brave.Browser)
        ;;
    3)
        BROWSER_APP="org.mozilla.firefox"
        FLATPAK_APPS+=(org.mozilla.firefox)
        ;;
    0)
        ;;
esac

###############################################
# Install Flatpaks
###############################################
flatpak install -y --system flathub "${FLATPAK_APPS[@]}"

###############################################
# Browser override (dynamic)
###############################################
if [ -n "$BROWSER_APP" ]; then
    runuser -u "$TARGET_USER" -- bash -c "
        flatpak override --user $BROWSER_APP \
        --nofilesystem=host \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=x11
    "
fi
