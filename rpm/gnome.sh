#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"

###############################################
# Gnome
###############################################
dnf install -y @gnome-desktop --exclude=gnome-boxes

systemctl enable gdm
systemctl set-default graphical.target

dnf install -y \
    gnome-tweaks \
    gnome-extensions-app \
    gnome-shell-extension-dash-to-panel \
    gnome-shell-extension-system-monitor \
    gnome-sound-recorder \
    virt-viewer

###############################################
# Flatpak
###############################################
flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# Variables
###############################################
BROWSER_APP="io.gitlab.librewolf-community"
TORRENT_APP="de.haeckerfelix.Fragments"

FLATPAK_APPS=(
    com.github.tchx84.Flatseal
    com.github.PintaProject.Pinta
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