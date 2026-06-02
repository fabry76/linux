#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="$1"
FLATPAK_BROWSER="${2:-0}"

###############################################
# KDE Plasma
###############################################
apt-mark hold plasma-browser-integration konqueror

apt-get install -y \
    kde-plasma-desktop \
    konsole \
    ark \
    kalk \
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
    skanpage

###############################################
# Firewall
###############################################
apt-get install -y ufw
if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
   sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
ufw allow mdns
ufw --force enable

###############################################
# KDE Flatpak
###############################################
apt-get install -y \
    flatpak \
    plasma-discover-backend-flatpak \
    xdg-desktop-portal-kde \
    kde-config-flatpak

flatpak remote-add --if-not-exists \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

FLATPAK_APPS=(
    org.gtk.Gtk3theme.Breeze
    org.onlyoffice.desktopeditors
    org.kde.ktorrent
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
    "flatpak override --user org.onlyoffice.desktopeditors --env=GTK_USE_PORTAL=1 --env=GTK_THEME=Breeze:dark"

runuser -u "$TARGET_USER" -- bash -c \
    "flatpak override --user org.kde.ktorrent --nofilesystem=host --filesystem=xdg-download"

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