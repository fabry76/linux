#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

###############################################
# Arguments and environment validation
###############################################
TARGET_USER="${1:?Missing TARGET_USER (first argument)}"
DESKTOP_CHOICE="${DESKTOP_CHOICE:?DESKTOP_CHOICE is not defined}"

case "$DESKTOP_CHOICE" in
    1)
        DESKTOP_ENV="kde"
        ;;
    2)
        DESKTOP_ENV="gnome"
        ;;
    *)
        echo "ERROR: Unsupported desktop choice: $DESKTOP_CHOICE" >&2
        exit 1
        ;;
esac

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)." >&2
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: User $TARGET_USER not found." >&2
    exit 1
fi

case "$DESKTOP_ENV" in
    kde|gnome)
        ;;
    *)
        echo "ERROR: Unsupported desktop environment: $DESKTOP_ENV" >&2
        echo "Supported values: kde, gnome" >&2
        exit 1
        ;;
esac

###############################################
# Execute commands as the target user
###############################################
run_as_user() {
    runuser -u "$TARGET_USER" -- \
        env \
        HOME="$TARGET_HOME" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        "$@"
}

###############################################
# Detect native package manager
###############################################
if command -v apt-get >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
else
    echo "ERROR: No supported package manager found." >&2
    exit 1
fi

###############################################
# Native Flatpak integration packages
###############################################
case "$PACKAGE_MANAGER:$DESKTOP_ENV" in
    apt:kde)
        NATIVE_PACKAGES=(
            flatpak
            plasma-discover-backend-flatpak
            xdg-desktop-portal-kde
            kde-config-flatpak
        )
        ;;

    apt:gnome)
        NATIVE_PACKAGES=(
            flatpak
            xdg-desktop-portal-gnome
            gnome-software-plugin-flatpak
        )
        ;;

    dnf:kde)
        NATIVE_PACKAGES=(
            flatpak
            plasma-discover-flatpak
            xdg-desktop-portal-kde
        )
        ;;

    dnf:gnome)
        NATIVE_PACKAGES=(
            flatpak
            gnome-software
            xdg-desktop-portal-gnome
        )
        ;;
esac

###############################################
# Install native integration packages
###############################################
case "$PACKAGE_MANAGER" in
    apt)
        apt-get install -y "${NATIVE_PACKAGES[@]}"
        ;;

    dnf)
        dnf install -y "${NATIVE_PACKAGES[@]}"
        ;;
esac

###############################################
# Configure Flathub system-wide
###############################################
flatpak remote-add \
    --if-not-exists \
    --system \
    flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# Flatpak application definitions
###############################################
BROWSER_APP="io.gitlab.librewolf-community"

case "$DESKTOP_ENV" in
    kde)
        TORRENT_APP="org.qbittorrent.qBittorrent"

        FLATPAK_APPS=(
            org.gtk.Gtk3theme.Breeze
            "$TORRENT_APP"
            "$BROWSER_APP"
        )
        ;;

    gnome)
        TORRENT_APP="de.haeckerfelix.Fragments"

        FLATPAK_APPS=(
            com.github.tchx84.Flatseal
            com.github.PintaProject.Pinta
            "$TORRENT_APP"
            "$BROWSER_APP"
        )
        ;;
esac

###############################################
# Install Flatpak applications
###############################################
flatpak install \
    -y \
    --noninteractive \
    --system \
    flathub \
    "${FLATPAK_APPS[@]}"

###############################################
# Browser security overrides
###############################################
run_as_user flatpak override \
    --user \
    "$BROWSER_APP" \
    --nofilesystem=host \
    --filesystem=xdg-download \
    --nodevice=all \
    --nosocket=x11 \
    --nosocket=pcsc \
    --nosocket=cups

###############################################
# Torrent application security overrides
###############################################
run_as_user flatpak override \
    --user \
    "$TORRENT_APP" \
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

###############################################
# Finished
###############################################
echo
echo "Flatpak configuration completed."
echo "Package manager: $PACKAGE_MANAGER"
echo "Desktop environment: $DESKTOP_ENV"
