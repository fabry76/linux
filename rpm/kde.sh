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
    kalk

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
BROWSER_APP="io.gitlab.librewolf-community"
TORRENT_APP="org.kde.ktorrent"

FLATPAK_APPS=(
        org.gtk.Gtk3theme.Breeze
        "$TORRENT_APP"
        "$BROWSER_APP"
    )

###############################################
# Install Flatpaks
###############################################
flatpak install -y --system flathub "${FLATPAK_APPS[@]}"

###############################################
# Browser override
###############################################
if [ -n "$BROWSER_APP" ]; then
    runuser -u "$TARGET_USER" -- bash -c "
        flatpak override --user '$BROWSER_APP' \
        --nofilesystem=host \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=x11 \
        --nosocket=pcsc \
        --nosocket=cups
    "
fi

###############################################
# BitTorrent override
###############################################
runuser -u "$TARGET_USER" -- bash -c "
    flatpak override --user '$TORRENT_APP' \
    --nofilesystem=host \
    --nofilesystem=home \
    --filesystem=xdg-download \
    --nodevice=all \
    --nosocket=pulseaudio \
    --nosocket=cups \
    --nosocket=pcsc \
    --nosocket=ssh-auth \
    --nosocket=x11 \
    --nosocket=fallback-x11
"