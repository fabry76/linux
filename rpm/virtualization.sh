dnf install -y  qemu-kvm libvirt virt-install virt-viewer
systemctl enable libvirtd

#!/bin/bash
set -euo pipefail

TARGET_USER="$1"
DESKTOP_CHOICE="$2"

case "$DESKTOP_CHOICE" in
    1)
        echo "Installing KDE virtualization stack..."

        dnf install -y \
            virt-manager \
            qemu-kvm \
            libvirt \
            virt-install \
            libvirt-client \
            virt-viewer

        usermod -aG libvirt,kvm "$TARGET_USER"
        systemctl enable libvirtd
        systemctl enable cockpit.socket

        echo "Virtualization stack installed."
        ;;

    2)
        echo "Installing GNOME Boxes..."

        flatpak install -y --system flathub org.gnome.Boxes

        echo "GNOME Boxes installed."
        ;;
esac