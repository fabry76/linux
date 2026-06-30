#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"
OFFICE_CHOICE="${3:-0}"

###############################################
# KDE Plasma base
###############################################
apt-get install -y \
    plasma-desktop \
    plasma-workspace \
    sddm \
    dolphin \
    kate \
    kdialog \
    kfind \
    konsole \
    ark \
    udisks2 \
    upower \
    kcalc \
    isoimagewriter \
    kolourpaint \
    gwenview \
    okular \
    okular-extra-backends \
    kcharselect \
    kcolorchooser \
    filelight \
    krecorder \
    plasma-workspace-wallpapers \
    inotify-tools \
    libnotify-bin \
    mpv \
    print-manager \
    skanpage \
    ktorrent

###############################################
# Firewall
###############################################
apt-get install -y ufw

ufw allow mdns
ufw --force enable

###############################################
# KDE Flatpak base setup
###############################################
apt-get install -y \
    flatpak \
    plasma-discover-backend-flatpak \
    xdg-desktop-portal-kde \
    kde-config-flatpak

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# Variables
###############################################
BROWSER_APP=""
OFFICE_APP=""

FLATPAK_APPS=(
    org.gtk.Gtk3theme.Breeze
)

###############################################
# Office selection
###############################################
case "$OFFICE_CHOICE" in
    1)
        OFFICE_APP="org.onlyoffice.desktopeditors"
        FLATPAK_APPS+=(org.onlyoffice.desktopeditors)
        ;;
    2)
        OFFICE_APP="org.libreoffice.LibreOffice"
        FLATPAK_APPS+=(org.libreoffice.LibreOffice)
        ;;
    3)
        OFFICE_APP="com.collaboraoffice.Office"
        FLATPAK_APPS+=(com.collaboraoffice.Office)
        ;;
    0)
        ;;
esac

###############################################
# Install Flatpaks
###############################################
flatpak install -y --system flathub "${FLATPAK_APPS[@]}"

###############################################
# Office override (dynamic)
###############################################
if [ -n "$OFFICE_APP" ]; then
    runuser -u "$TARGET_USER" -- bash -c "
        flatpak override --user $OFFICE_APP \
        --env=GTK_USE_PORTAL=1 \
        --env=GTK_THEME=Breeze:dark
    "
fi