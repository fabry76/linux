#!/usr/bin/env bash
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
DISTRO="ubuntu"

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
# Questions
###############################################
source "$GIT_DIR/questions.sh"
run_installer_questions

###############################################
# Dependencies for key management & repositories
###############################################
apt-get install -y gpg curl
install -d -m 0755 /etc/apt/keyrings

###############################################
# Initial Firmware, Drivers and Utilities
###############################################
apt-get install -y intel-media-va-driver-non-free

###############################################
# Desktop Environment
###############################################
case "$DESKTOP_CHOICE" in
    1)
        echo
        echo "Installing KDE Plasma..."
        bash "$SCRIPT_DIR/kde.sh" "$TARGET_USER" "$FLATPAK_BROWSER"
        ;;
    2)
        echo
        echo "Installing GNOME..."
        bash "$SCRIPT_DIR/gnome.sh" "$TARGET_USER" "$FLATPAK_BROWSER"
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
            bash "$SCRIPT_DIR/firefox.sh"
            ;;
    esac
done

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

##############################################
# Common Utilities
###############################################
apt-get install -y timeshift fastfetch unrar fwupd debsums starship nvme-cli rclone wakeonlan

###############################################
# Multimedia & Extras
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install -y apt-get install -y ffmpeg ffmpegthumbnailer ubuntu-restricted-extras lsp-plugins-lv2

###############################################
# Fonts & Icons
###############################################
apt-get install -y fonts-crosextra-carlito fonts-crosextra-caladea fonts-firacode fonts-noto
apt-get install -y papirus-icon-theme yaru-theme-icon

###############################################
# Printing & Scanning
###############################################
apt-get install -y \
  cups \
  printer-driver-all \
  printer-driver-cups-pdf \
  sane

usermod -aG lpadmin "$TARGET_USER"
systemctl enable cups

###############################################
# Firewall
###############################################
apt-get install -y ufw

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
    apt-get install -y cifs-utils
    bash "$GIT_DIR/fastgate.sh"
fi

###############################################
# Hardening
###############################################
if [ -f "$SCRIPT_DIR/hard_deb.sh" ]; then
  if [[ "$RUN_HARDENING" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/hard_ubu.sh"
  fi
fi

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

echo "System installation completed."

###############################################
# User session script
###############################################
USER_SCRIPT="$GIT_DIR/user_customization.sh"

if [ -f "$USER_SCRIPT" ]; then
    echo "Running user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE="$DESKTOP_CHOICE" bash "$USER_SCRIPT"
fi
