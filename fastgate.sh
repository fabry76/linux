#!/bin/bash
set -euo pipefail

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
    echo "Run as root (sudo)"
    exit 1
fi

###############################################
# Helper: write if changed
###############################################
write_if_changed() {
    local file="$1"
    local content="$2"

    if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
        return 0
    fi

    printf "%s" "$content" > "$file"
}

###############################################
# Variables
###############################################
TARGET_USER="${1:-${SUDO_USER:-${USER:-root}}}"

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

MOUNT_POINT="$TARGET_HOME/Fastgate"
CRED_FILE="/etc/samba/fastgate.creds"
SERVER="//192.168.1.254/samba/usb1_1"

USER_ID=$(id -u "$TARGET_USER")
GROUP_ID=$(id -g "$TARGET_USER")

###############################################
# Credentials check
###############################################
if [ ! -f "$CRED_FILE" ]; then
    echo "Missing credentials file:"
    echo "  $CRED_FILE"
    exit 1
fi

if ! grep -q "^username=" "$CRED_FILE"; then
    echo "Invalid credentials file (username missing)"
    exit 1
fi

if ! grep -q "^password=" "$CRED_FILE"; then
    echo "Invalid credentials file (password missing)"
    exit 1
fi

###############################################
# Mount point
###############################################
systemctl is-active --quiet NetworkManager || systemctl start NetworkManager

mkdir -p "$MOUNT_POINT"
chown "$TARGET_USER:$TARGET_USER" "$MOUNT_POINT"

###############################################
# systemd mount unit
###############################################
MOUNT_NAME=$(systemd-escape -p "$MOUNT_POINT")
MOUNT_UNIT="/etc/systemd/system/${MOUNT_NAME}.mount"

UNIT_CONTENT=$(cat <<EOF
[Unit]
Description=Fastgate SMB Mount
After=network-online.target remote-fs-pre.target
Wants=network-online.target

[Mount]
What=${SERVER}
Where=${MOUNT_POINT}
Type=cifs
Options=_netdev,vers=1.0,credentials=${CRED_FILE},iocharset=utf8,uid=${USER_ID},gid=${GROUP_ID},file_mode=0755,dir_mode=0755,cache=loose,actimeo=30,nofail,soft,noserverino

[Install]
WantedBy=multi-user.target
EOF
)

write_if_changed "$MOUNT_UNIT" "$UNIT_CONTENT"

###############################################
# Enable mount
###############################################
systemctl daemon-reload
systemctl enable "${MOUNT_NAME}.mount"

###############################################
# Mount now
###############################################
if ! mountpoint -q "$MOUNT_POINT"; then
    systemctl restart "${MOUNT_NAME}.mount" || true
fi

###############################################
# Done
###############################################
echo
echo "Fastgate SMB configured."
echo "Share:        $SERVER"
echo "Mount point:  $MOUNT_POINT"
echo "Credentials:  $CRED_FILE"
echo "Systemd unit: $MOUNT_UNIT"