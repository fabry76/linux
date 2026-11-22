#!/usr/bin/env bash
set -euo pipefail

###############################################
# Args
###############################################
TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"

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
    gnome-themes-extra \
    gnome-sound-recorder

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
TORRENT_APP="de.haeckerfelix.Fragments"

FLATPAK_APPS=(
    com.github.tchx84.Flatseal
    com.github.PintaProject.Pinta
    "$TORRENT_APP"
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