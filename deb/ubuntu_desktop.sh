#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export APT_LISTCHANGES_FRONTEND=none
# Skip needrestart during provisioning; reboot at the end instead.
export NEEDRESTART_SUSPEND=1

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# APT preparation
###############################################
# Stop automatic package activity
systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl stop apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

# Wait for any existing package operation to finish
while fuser /var/lib/dpkg/lock-frontend \
            /var/lib/dpkg/lock \
            /var/cache/apt/archives/lock \
            /var/cache/debconf/config.dat >/dev/null 2>&1; do
    echo "Waiting for another package process to finish..."
    sleep 2
done

###############################################
# Variables
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(dirname "$SCRIPT_DIR")"
DISTRO="ubuntu"
export DISTRO

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

###############################################
# Initial selection
###############################################
while :; do
    read -rp "Do you want to mount the Fastgate SMB share? (Y/n): " RUN_FASTGATE
    RUN_FASTGATE="${RUN_FASTGATE:-Y}"
    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn])$ ]] && break
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
        while :; do
            read -rp "Fastgate credentials already exist. Update credentials? (y/N): " CONFIRM
            CONFIRM="${CONFIRM:-N}"
            [[ "$CONFIRM" =~ ^([Yy]|[Nn])$ ]] && break
            echo "Please answer y or n."
        done
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
        OLD_UMASK="$(umask)"
        umask 077
        cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF
        umask "$OLD_UMASK"
        chown root:root "$CRED_FILE"
        chmod 600 "$CRED_FILE"
    fi
fi
echo

###############################################
# Update repositories
###############################################
apt-get update
apt-get -y upgrade

###############################################
# Dependencies for key management + debconf preseed
###############################################
apt-get install -y curl debconf-utils
install -d -m 0755 /etc/apt/keyrings

echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" \
  | debconf-set-selections

###############################################
# Packages from the Ubuntu archive (single apt call)
###############################################
PKGS=(
  # Base system & firmware
  nvme-cli

  # Desktop & GNOME utilities
  gnome-shell-extension-manager
  gnome-weather
  gnome-calendar
  gnome-tweaks
  gnome-snapshot
  gnome-sound-recorder
  showtime

  # Applications & Utilities
  vim
  htop
  fastfetch
  timeshift
  apt-show-versions
  rclone
  unrar
  starship
  debsums
  wakeonlan

  # Multimedia and Extra
  ffmpeg
  ffmpegthumbnailer
  ubuntu-restricted-extras
  fonts-firacode
  lsp-plugins-lv2

  # Firewall
  gufw

  # Printing & Scanning
  cups
  printer-driver-all
  printer-driver-cups-pdf
  sane
  simple-scan
)

# Intel media driver only when an Intel GPU is present (useless in most VMs)
if grep -qs 0x8086 /sys/class/drm/card*/device/vendor; then
  PKGS+=(intel-media-va-driver-non-free)
fi

if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
  PKGS+=(cifs-utils)
fi

apt-get install -y "${PKGS[@]}"

###############################################
# Other apps
###############################################
bash "$SCRIPT_DIR/vscode.sh"
bash "$SCRIPT_DIR/brave.sh"
bash "$SCRIPT_DIR/nextcloud.sh"

###############################################
# Snaps
###############################################
snap wait system seed.loaded
echo "Installing snaps (can take several minutes, no progress shown)..."
snap install pinta fragments

###############################################
# Firewall
###############################################
ufw default deny incoming
ufw default allow outgoing
ufw allow mdns
ufw --force enable

###############################################
# Printing & Scanning
###############################################
usermod -aG lpadmin "$TARGET_USER"
systemctl enable cups

###############################################
# GRUB
###############################################
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub

sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"/' \
  /etc/default/grub

update-grub

###############################################
# Locale
###############################################
grep -q "^it_IT.UTF-8 UTF-8" /etc/locale.gen || \
  printf "it_IT.UTF-8 UTF-8\n" >> /etc/locale.gen

locale-gen

###############################################
# Fastgate
###############################################
if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    bash "$GIT_DIR/fastgate.sh"
fi

###############################################
# Hardening
###############################################
bash "$SCRIPT_DIR/hard_ubu.sh"

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

echo
echo "Installation completed. Reboot recommended."

###############################################
# User session script
###############################################
runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE=2 bash "$GIT_DIR/user_customization.sh"
