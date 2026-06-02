#!/bin/bash
set -euo pipefail

TARGET_USER="$1"

apt-get install -y virt-manager virt-viewer qemu-kvm

systemctl enable libvirtd

usermod -aG libvirt,kvm "$TARGET_USER"

echo "Virt-Manager installed."