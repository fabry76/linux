#!/bin/bash
set -euo pipefail

TARGET_USER="$1"

apt-get install -y cockpit-machines virt-viewer qemu-kvm libvirt-daemon-system
usermod -aG libvirt,kvm "$TARGET_USER"
sudo systemctl enable libvirtd

echo "Cockpit installed."
