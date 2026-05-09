#!/bin/bash
set -euo pipefail

###############################################
# Config
###############################################
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

MOUNT_POINT="$TARGET_HOME/Fastgate"
CRED_FILE="/etc/samba/fastgate.creds"
FSTAB_LINE="//192.168.1.254/samba/usb1_1 $MOUNT_POINT cifs _netdev,x-systemd.automount,vers=1.0,credentials=$CRED_FILE,iocharset=utf8,uid=$(id -u "$TARGET_USER"),gid=$(id -g "$TARGET_USER"),file_mode=0755,dir_mode=0755,cache=loose,actimeo=30,nofail,soft,noserverino 0 0"

###############################################
# Check root
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Install dependency
###############################################
apt-get install -y cifs-utils

###############################################
# Create mount point
###############################################
mkdir -p "$MOUNT_POINT"
chown "$TARGET_USER":"$TARGET_USER" "$MOUNT_POINT"

###############################################
# Ask credentials
###############################################
if [ -f "$CRED_FILE" ]; then
  echo "Credentials already exist."
  read -rp "Do you want to update them? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Keeping existing credentials."
    exit 0
  fi
fi

echo "=== NAS credentials setup ==="
read -rp "Username: " NAS_USER
read -rsp "Password: " NAS_PASS
echo

###############################################
# Create credentials file
###############################################
cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

chmod 600 "$CRED_FILE"
chown root:root "$CRED_FILE"

###############################################
# Add to fstab if not exists
###############################################
grep -qxF "$FSTAB_LINE" /etc/fstab || echo "$FSTAB_LINE" >> /etc/fstab

###############################################
# Done
###############################################
echo "Done."
echo "Mount point: $MOUNT_POINT"
echo "Credentials stored securely in $CRED_FILE"

