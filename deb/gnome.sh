#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
OFFICE_CHOICE="${3:-0}"

###############################################
# Gnome base
###############################################
apt-get install -y --no-install-recommends \
    gnome-core \
    ptyxis \
    papers \
    showtime \
    network-manager \
    gnome-tweaks \
    gnome-shell-extension-manager \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-system-monitor \
    gnome-shell-extension-apps-menu
    
###############################################
# Firewall
###############################################
apt-get install -y gufw

ufw allow mdns
ufw --force enable

###############################################
# Gnome Flatpak base setup
###############################################
apt-get install -y \
    flatpak \
    xdg-desktop-portal-gnome \
    gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# Variables
###############################################
OFFICE_APP=""

FLATPAK_APPS=(
    org.qbittorrent.qBittorrent
    com.github.tchx84.Flatseal
    com.github.PintaProject.Pinta
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
# Gnome apps override
###############################################
runuser -u "$TARGET_USER" -- bash -c \
    "flatpak override --user org.qbittorrent.qBittorrent --nofilesystem=host --filesystem=xdg-download"
