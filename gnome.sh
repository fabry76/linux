#!/usr/bin/env bash
set -euo pipefail

apt-get install -y \
    gnome-core \
    gnome-software \
    gnome-software-plugin-flatpak

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
    xdg-desktop-portal-gnome

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y --system flathub \
    org.onlyoffice.desktopeditors \
    org.mozilla.firefox