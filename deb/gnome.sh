#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

###############################################
# Arguments and environment validation
###############################################
TARGET_USER="${1:?Missing TARGET_USER (first argument)}"
INSTALL_FLATPAK="${2:-n}"
DISTRO="${DISTRO:?DISTRO is not defined (the calling script must export it)}"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)." >&2
    exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$TARGET_HOME" ]]; then
    echo "ERROR: User $TARGET_USER not found." >&2
    exit 1
fi

###############################################
# Execute commands as the target user
###############################################
run_as_user() {
    runuser -u "$TARGET_USER" -- env HOME="$TARGET_HOME" "$@"
}

###############################################
# Distribution-specific GNOME base
###############################################
case "$DISTRO" in
    debian)
        apt-get install -y \
            gnome-core
        ;;

    ubuntu)
        apt-get install -y \
            ubuntu-desktop-minimal
        ;;

    *)
        echo "ERROR: Unsupported distribution: $DISTRO" >&2
        exit 1
        ;;
esac

###############################################
# Common GNOME applications
###############################################
GNOME_PKGS=(
    ptyxis
    papers
    showtime
    gnome-tweaks
    gnome-shell-extension-manager
    gnome-shell-extension-system-monitor
    gnome-sound-recorder
)

apt-get install -y "${GNOME_PKGS[@]}"

###############################################
# Graphical target
###############################################
systemctl set-default graphical.target

###############################################
# Optional Flatpak installation
###############################################
if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then

    ###############################################
    # Flatpak and GNOME integration
    ###############################################
    apt-get install -y \
        flatpak \
        xdg-desktop-portal-gnome \
        gnome-software-plugin-flatpak

    ###############################################
    # Flathub
    ###############################################
    flatpak remote-add --if-not-exists --system \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    ###############################################
    # Flatpak applications
    ###############################################
    BROWSER_APP="io.gitlab.librewolf-community"
    TORRENT_APP="de.haeckerfelix.Fragments"

    FLATPAK_APPS=(
        com.github.tchx84.Flatseal
        com.github.PintaProject.Pinta
        "$TORRENT_APP"
        "$BROWSER_APP"
    )

    flatpak install -y --noninteractive --system \
        flathub "${FLATPAK_APPS[@]}"

    ###############################################
    # LibreWolf security overrides
    ###############################################
    run_as_user flatpak override --user "$BROWSER_APP" \
        --nofilesystem=host \
        --filesystem=xdg-download \
        --nodevice=all \
        --nosocket=x11 \
        --nosocket=pcsc \
        --nosocket=cups

    ###############################################
    # Fragments security overrides
    ###############################################
    run_as_user flatpak override --user "$TORRENT_APP" \
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
fi
