set -euo pipefail

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Variables
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(dirname "$SCRIPT_DIR")"

###############################################
# Functions
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
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

################################################
# Initial selection
################################################
while :; do
    read -rp "Do you want to mount the Fastgate SMB share? (y/N): " RUN_FASTGATE
    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then

    CRED_FILE="/etc/samba/fastgate.creds"
    
    install -d -m 700 /etc/samba

    CRED_STATE="missing"

    if [ -f "$CRED_FILE" ]; then
        if grep -q "^username=" "$CRED_FILE" &&
           grep -q "^password=" "$CRED_FILE"; then
            CRED_STATE="valid"
        else
            CRED_STATE="invalid"
        fi
    fi

    if [ "$CRED_STATE" = "valid" ]; then
        echo
        echo "Fastgate credentials already exist."
        read -rp "Update credentials? (y/N): " CONFIRM

        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            CRED_STATE="update"
        fi
    fi

    if [ "$CRED_STATE" = "missing" ] ||
       [ "$CRED_STATE" = "invalid" ] ||
       [ "$CRED_STATE" = "update" ]; then

        echo
        echo "=== Fastgate credentials ==="

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
fi

################################################
# RPM Fusion
################################################
dnf install -y \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

###############################################
# Gnome
###############################################
dnf install -y @gnome-desktop \
    --setopt=install_weak_deps=False \
    --exclude=gnome-boxes \
    --exclude=gnome-maps

systemctl enable gdm
systemctl set-default graphical.target

dnf install -y \
    gnome-tweaks \
    gnome-extensions-app \
    gnome-shell-extension-dash-to-dock

###############################################
# Other apps
###############################################
#bash "$SCRIPT_DIR/vscode.sh"
#bash "$SCRIPT_DIR/brave.sh"

###############################################
# Multimedia
###############################################
dnf install -y \
  ffmpeg \
  ffmpegthumbnailer \
  gstreamer1-libav \
  gstreamer1-plugin-openh264

###############################################
# Fonts & Icons
###############################################
dnf install -y \
    mscorefonts \
    google-crosextra-carlito-fonts \
    google-crosextra-caladea-fonts \
    fira-code-fonts \
    papirus-icon-theme

###############################################
# Applications & Utilities
###############################################
dnf install -y \
  vim \
  htop \
  fastfetch \
  curl \
  timeshift \
  apt-show-versions \
  rclone \
  unrar \
  starship

###############################################
# Fastgate
###############################################
if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    dnf install -y cifs-utils
    bash "$GIT_DIR/fastgate.sh" "$TARGET_USER"
fi

################################################
# User Script
################################################
bash "$GIT_DIR/gnome_user.sh"