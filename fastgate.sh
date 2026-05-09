#!/bin/bash
set -euo pipefail

###############################################
# Config
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

MOUNT_POINT="$TARGET_HOME/Fastgate"
CRED_FILE="/etc/samba/fastgate.creds"

SERVER="//192.168.1.254/samba/usb1_1"

USER_ID=$(id -u "$TARGET_USER")
GROUP_ID=$(id -g "$TARGET_USER")

FSTAB_LINE="$SERVER $MOUNT_POINT cifs _netdev,x-systemd.automount,vers=1.0,credentials=$CRED_FILE,iocharset=utf8,uid=$USER_ID,gid=$GROUP_ID,file_mode=0755,dir_mode=0755,cache=loose,actimeo=30,nofail,soft,noserverino 0 0"

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Dependency
###############################################
apt-get install -y cifs-utils

###############################################
# Mount point setup (idempotente vera)
###############################################
runuser -u "$TARGET_USER" -- mkdir -p "$MOUNT_POINT"

###############################################
# Detect credentials state (VERA logica idempotente)
###############################################
CRED_STATE="missing"

if [ -f "$CRED_FILE" ]; then
  if grep -q "^username=" "$CRED_FILE" && grep -q "^password=" "$CRED_FILE"; then
    CRED_STATE="valid"
  else
    CRED_STATE="invalid"
  fi
fi

###############################################
# Credential handling
###############################################
if [ "$CRED_STATE" = "valid" ]; then
  echo "Credentials already present."

  read -rp "Update credentials? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Keeping existing credentials."
  else
    CRED_STATE="update"
  fi
fi

if [ "$CRED_STATE" = "missing" ] || [ "$CRED_STATE" = "invalid" ] || [ "$CRED_STATE" = "update" ]; then
  echo "=== NAS credentials setup ==="
  read -rp "Username: " NAS_USER
  read -rsp "Password: " NAS_PASS
  echo

  umask 077
  cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

  chown root:root "$CRED_FILE"
  chmod 600 "$CRED_FILE"
fi

###############################################
# fstab (idempotente vera)
###############################################
if ! grep -Fq "$SERVER $MOUNT_POINT" /etc/fstab; then
  echo "$FSTAB_LINE" >> /etc/fstab
fi

###############################################
# Done
###############################################
echo "Done."
echo "Mount point: $MOUNT_POINT"
echo "Credentials: $CRED_FILE"