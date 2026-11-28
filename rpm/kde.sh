#!/usr/bin/env bash
set -euo pipefail

###############################################
# Arguments and environment validation
###############################################
TARGET_USER="${1:?Missing TARGET_USER (first argument)}"
INSTALL_FLATPAK="${2:-n}"

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
# KDE Plasma and application packages
###############################################
KDE_PKGS=(
    # KDE core
    plasma-desktop
    plasma-login-manager
    kwin
    plasma-nm
    plasma-pa
    kscreen

    # KDE apps
    konsole
    dolphin
    ark
    spectacle
    kwrite
    isoimagewriter
    kolourpaint
    gwenview
    okular
    kcolorchooser
    kcharselect
    krecorder
    skanpage
    kclock
    kamoso
    kalk
    filelight
    mpv
    transmission-qt

    # KDE various
    plasma-systemmonitor
    plasma-print-manager
    kde-partitionmanager
    kwalletmanager5
    pam-kwallet
    bluedevil
    kinfocenter
    kdegraphics-thumbnailers
    kde-gtk-config
    breeze-gtk
)

###############################################
# Install KDE Plasma
###############################################
dnf install -y "${KDE_PKGS[@]}"

###############################################
# Display manager
###############################################
systemctl enable plasmalogin
systemctl set-default graphical.target

###############################################
# Optional Flatpak installation
###############################################
if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then
    bash "$GIT_DIR/flatpak.sh" "$TARGET_USER"
fi
