#!/bin/bash
set -euo pipefail

TARGET_USER="$1"

apt-get install -y cockpit cockpit-machines virt-viewer

systemctl enable cockpit.socket

usermod -aG libvirt,kvm "$TARGET_USER"

echo "Cockpit installed."
