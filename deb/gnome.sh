#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"
OFFICE_CHOICE="${3:-0}"

###############################################
# Gnome base
###############################################
apt-mark hold firefox-esr

apt-get install -y \
    gnome-core \
    showtime+ \
    papers+ \
    gnome-tweaks \
    gnome-shell-extension-manager \
    gnome-shell-extension-dash-to-panel
    
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
BROWSER_APP=""
OFFICE_APP=""

FLATPAK_APPS=(
    com.transmissionbt.Transmission
    com.github.tchx84.Flatseal
)

###############################################
# Browser selection
###############################################
case "$FLATPAK_BROWSER" in
    1)
        BROWSER_APP="org.mozilla.firefox"
        FLATPAK_APPS+=(org.mozilla.firefox)
        ;;
    2)
        BROWSER_APP="com.brave.Browser"
        FLATPAK_APPS+=(com.brave.Browser)
        ;;
    3)
        BROWSER_APP="io.gitlab.librewolf-community"
        FLATPAK_APPS+=(io.gitlab.librewolf-community)
        ;;
    0)
        ;;
esac

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
    "flatpak override --user com.transmissionbt.Transmission --nofilesystem=host --filesystem=xdg-download"

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