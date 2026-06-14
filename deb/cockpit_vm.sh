#!/bin/bash
set -euo pipefail

TARGET_USER="${1:?Usage: $0 <user>}"

apt-get update
apt-get install -y \
cockpit-machines \
qemu-kvm \
libvirt-daemon-system \
virtinst \
libvirt-clients \
bridge-utils \
virt-viewer

# --- LIBVIRT CONFIG (IDEMPOTENT) ---

LIBVIRT_CONF="/etc/libvirt/qemu.conf"
TMP_CONF="$(mktemp)"

cat > "$TMP_CONF" <<'EOF'
user = "libvirt-qemu"
group = "kvm"

# Prevent root-owned disks/snapshots
dynamic_ownership = 1
EOF

if [ ! -f "$LIBVIRT_CONF" ] || ! cmp -s "$TMP_CONF" "$LIBVIRT_CONF"; then
    mv "$TMP_CONF" "$LIBVIRT_CONF"
else
    rm -f "$TMP_CONF"
fi

# --- STORAGE BASELINE ---

LIBVIRT_IMG="/var/lib/libvirt/images"

mkdir -p "$LIBVIRT_IMG"

if [ "$(stat -c "%U:%G" "$LIBVIRT_IMG")" != "libvirt-qemu:kvm" ]; then
    chown libvirt-qemu:kvm "$LIBVIRT_IMG"
fi

if [ "$(stat -c "%a" "$LIBVIRT_IMG")" != "750" ]; then
    chmod 750 "$LIBVIRT_IMG"
fi

# --- USER GROUPS ---

usermod -aG libvirt,kvm "$TARGET_USER"

# enable libvirt socket (Debian-safe)
systemctl enable libvirtd >/dev/null 2>&1 || true

echo "Cockpit + libvirt installed safely."
