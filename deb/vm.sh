#!/bin/bash
set -euo pipefail

TARGET_USER="$1"
DESKTOP_CHOICE="$2"

case "$DESKTOP_CHOICE" in
    1)
        echo "Installing KDE virtualization stack..."

        apt-get install -y \
            virt-manager \
            cockpit-machines \
            qemu-kvm \
            libvirt-daemon-system \
            virtinst \
            libvirt-clients \
            bridge-utils \
            virt-viewer

        usermod -aG libvirt,kvm "$TARGET_USER"

        systemctl enable libvirtd

        echo "Cockpit + libvirt installed."
        ;;

    2)
        echo "Installing GNOME Boxes..."

        flatpak install -y --system flathub org.gnome.Boxes

        echo "GNOME Boxes installed."
        ;;
esac