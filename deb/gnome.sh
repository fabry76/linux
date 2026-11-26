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
# Paths
###############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(dirname "$SCRIPT_DIR")"

###############################################
# Distribution-specific GNOME base
###############################################
case "$DISTRO" in
    debian)
        apt-get install -y --no-install-recommends \
            gnome-core \
            ptyxis+ \
            showtime+ \
            papers+ \
            network-manager \
            low-memory-monitor \
            gnome-themes-extra \
            gnome-shell-extension-system-monitor \
            gnome-shell-extension-dash-to-panel
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
    gnome-shell-extension-manager
    gnome-weather
    gnome-calendar
    gnome-tweaks
    gnome-snapshot
    gnome-sound-recorder
    gnome-firmware
    showtime
    gufw
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
    bash "$GIT_DIR/flatpak.sh" "$TARGET_USER"
fi

###############################################
# Ubuntu Snap applications
###############################################
if [[ "$DISTRO" == "ubuntu" ]]; then
    snap install \
        fragments \
        pinta \
        snap-store
fi
