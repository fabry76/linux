#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"

apt-get install -y \
    gnome-core \
    gnome-software
    
###############################################
# Firewall
###############################################
apt-get install -y gufw
if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
   sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
ufw allow mdns
ufw --force enable

###############################################
# Gnome Flatpak
###############################################

apt-get install -y \
    flatpak \
    xdg-desktop-portal-gnome \
    gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

FLATPAK_APPS=(
    org.onlyoffice.desktopeditors
    com.transmissionbt.Transmission
)

case "$FLATPAK_BROWSER" in
    1)
        FLATPAK_APPS+=(org.mozilla.firefox)
        ;;
    2)
        FLATPAK_APPS+=(com.brave.Browser)
        ;;
    3)
        FLATPAK_APPS+=(io.gitlab.librewolf-community)
        ;;
    0)
        ;;
esac

flatpak install -y --system flathub "${FLATPAK_APPS[@]}"

runuser -u "$TARGET_USER" -- bash -c \
    "flatpak override --user com.transmissionbt.Transmission --nofilesystem=host --filesystem=xdg-download"

case "$FLATPAK_BROWSER" in
    1)
        runuser -u "$TARGET_USER" -- bash -c \
            "flatpak override --user org.mozilla.firefox --nofilesystem=host --filesystem=xdg-download --nodevice=all --nosocket=x11"
        ;;
    2)
        runuser -u "$TARGET_USER" -- bash -c \
            "flatpak override --user com.brave.Browser --nofilesystem=host --filesystem=xdg-download --nodevice=all --nosocket=x11"
        ;;
    3)
        runuser -u "$TARGET_USER" -- bash -c \
            "flatpak override --user io.gitlab.librewolf-community --nofilesystem=host --filesystem=xdg-download --nodevice=all --nosocket=x11"
        ;;
    0)
        ;;
esac