#!/bin/bash
set -euo pipefail

TARGET_USER="$1"

apt-get install -y \
cockpit-machines \
qemu-kvm \
libvirt-daemon-system \
virtinst \
libvirt-clients \
bridge-utils \
virt-viewer \
dnsmasq

usermod -aG libvirt,kvm "$TARGET_USER"
sudo systemctl enable libvirtd

echo "Cockpit installed."
