#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export APT_LISTCHANGES_FRONTEND=none
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

apt_install() {
  apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@"
}

###############################################
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

###############################################
# System update command
###############################################
"$SCRIPT_DIR/ubuntu_update.sh"

###############################################
# Questions
###############################################
source "$GIT_DIR/questions.sh"
run_installer_questions

###############################################
# Base dependencies + debconf preseed
###############################################
apt-get update
apt_install gpg curl debconf-utils
install -d -m 0755 /etc/apt/keyrings

echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula boolean true" \
  | debconf-set-selections

###############################################
# Intel media driver (only if an Intel GPU is present)
###############################################
if grep -qs 0x8086 /sys/class/drm/card*/device/vendor; then
  apt_install intel-media-va-driver-non-free
fi

###############################################
# Desktop Environment
###############################################
case "$DESKTOP_CHOICE" in
    1)
        echo
        echo "Installing KDE Plasma..."
        bash "$SCRIPT_DIR/kde.sh" "$TARGET_USER" "$INSTALL_FLATPAK"
        ;;
    2)
        echo
        echo "Installing GNOME..."
        bash "$SCRIPT_DIR/gnome.sh" "$TARGET_USER" "$INSTALL_FLATPAK"
        ;;
esac

###############################################
# Browsers
###############################################
for browser in "${BROWSERS[@]}"; do
    browser="${browser// /}"

    case "$browser" in
        1)
            bash "$SCRIPT_DIR/brave.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/chrome.sh"
            ;;
        3)
            snap install firefox
            ;;
    esac
done

###############################################
# Packages from the Ubuntu archive (single apt call)
###############################################
PKGS=(
  # Fonts & icons
  fonts-crosextra-carlito fonts-crosextra-caladea fonts-firacode
  fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji
  papirus-icon-theme

  # Multimedia
  ffmpeg ffmpegthumbnailer ubuntu-restricted-extras lsp-plugins-lv2

  # Common utilities
  timeshift fastfetch unrar debsums starship nvme-cli rclone wakeonlan

  # Printing & scanning
  cups printer-driver-gutenprint printer-driver-cups-pdf sane
  
  # Firewall
  ufw
)

if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
  PKGS+=(cifs-utils)
fi

apt_install "${PKGS[@]}"

###############################################
# Office
###############################################
if [[ "$INSTALL_OFFICE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/nextcloud.sh"
fi

###############################################
# Visual Studio Code
###############################################
if [[ "$INSTALL_VSCODE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/vscode.sh"
fi

###############################################
# Printing configuration
###############################################
usermod -aG lpadmin "$TARGET_USER"
systemctl enable cups

###############################################
# Firewall
###############################################
ufw default deny incoming
ufw default allow outgoing
ufw allow 5353/udp
ufw --force enable

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
if [[ "$RUN_HARDENING" =~ ^[Yy]$ ]] && [ -f "$SCRIPT_DIR/hard_ubu.sh" ]; then
    bash "$SCRIPT_DIR/hard_ubu.sh"
fi

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

###############################################
# Network Manager only
###############################################
NETPLAN_FILE="/etc/netplan/99-NetworkManager.yaml"

NETPLAN_CONTENT=$(cat << 'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
)

write_if_changed "$NETPLAN_FILE" "$NETPLAN_CONTENT"
chown root:root "$NETPLAN_FILE"
chmod 600 "$NETPLAN_FILE"

systemctl enable NetworkManager
systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl disable systemd-networkd.socket 2>/dev/null || true
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true

netplan generate

###############################################
# User session script
###############################################
USER_SCRIPT="$GIT_DIR/user_customization.sh"

if [ -f "$USER_SCRIPT" ]; then
    echo "Running user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE="$DESKTOP_CHOICE" bash "$USER_SCRIPT"
fi
