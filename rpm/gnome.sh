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
# GNOME desktop
###############################################
dnf install -y \
    @gnome-desktop \
    --exclude=gnome-boxes

###############################################
# GNOME applications
###############################################
GNOME_PKGS=(
    gnome-tweaks
    gnome-extensions-app
    gnome-shell-extension-dash-to-panel
    gnome-shell-extension-system-monitor
    gnome-sound-recorder
    virt-viewer
)

dnf install -y "${GNOME_PKGS[@]}"

###############################################
# Display manager
###############################################
systemctl enable gdm
systemctl set-default graphical.target

###############################################
# Optional Flatpak installation
###############################################
if [[ "$INSTALL_FLATPAK" =~ ^[Yy]$ ]]; then
    bash "$GIT_DIR/flatpak.sh" "$TARGET_USER"
fi
