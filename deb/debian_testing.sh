#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

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

# Packages that do not exist in testing are collected here and reported at the end
SKIPPED=()

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

# Install only the packages that actually exist in the configured repositories.
# Missing ones are skipped (not fatal) and reported in the final summary.
install_available() {
  local available=()
  local pkg

  for pkg in "$@"; do
    if apt-cache show "$pkg" > /dev/null 2>&1; then
      available+=("$pkg")
    else
      echo "WARNING: '$pkg' not available in testing, skipping"
      SKIPPED+=("$pkg")
    fi
  done

  if [ "${#available[@]}" -gt 0 ]; then
    apt-get install -y "${available[@]}"
  fi
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
# Debian Repositories (testing only, no mixing)
###############################################
# Disable legacy sources.list
if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
  fi
fi

# Use the rolling suite name "testing" instead of a codename, so the
# system follows testing across releases and never silently stays on an old one.
#
# Notes:
#  - no "-security" suite: testing-security is not maintained, security fixes
#    reach testing through the normal "testing" suite via unstable
#  - no "-updates" suite: it does not exist as a regular suite for testing
#  - no stable/unstable lines on purpose: mixing suites causes broken dependencies
DEBIAN_SOURCES="/etc/apt/sources.list.d/debian.sources"

write_if_changed "$DEBIAN_SOURCES" "$(cat << 'EOF'
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: testing
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
)"

###############################################
# Update Repositories
###############################################
apt-get update
# full-upgrade (not upgrade): testing often needs to remove/replace packages
# during library transitions
apt-get -y full-upgrade

###############################################
# Initial Firmware, Drivers and Utilities
###############################################
# Checked one by one: names and splits of firmware packages can change in testing
install_available \
  firmware-linux \
  firmware-linux-nonfree \
  firmware-misc-nonfree \
  firmware-sof-signed \
  firmware-realtek \
  intel-media-va-driver-non-free \
  firmware-iwlwifi

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
# Common Utilities and Configurations
###############################################
# unattended-upgrades is intentionally left out: its default rules target the
# -security suite, which does not exist for testing. Update with full-upgrade.
install_available \
  timeshift vim htop fastfetch unrar plymouth-themes fwupd debsums starship \
  nvme-cli thermald wakeonlan

systemctl enable thermald

if plymouth-set-default-theme -l 2>/dev/null | grep -qx "lines"; then
    plymouth-set-default-theme lines -R
else
    echo "WARNING: plymouth theme 'lines' not found, keeping default"
fi

###############################################
# Multimedia
###############################################
install_available \
  ffmpeg gstreamer1.0-libav gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly lsp-plugins-lv2

###############################################
# Fonts & Icons
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
install_available \
  ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito \
  fonts-crosextra-caladea fonts-firacode fonts-noto
install_available papirus-icon-theme

###############################################
# Printing & Scanning
###############################################
apt-get install -y cups printer-driver-gutenprint printer-driver-cups-pdf
systemctl enable cups
usermod -aG lpadmin "$TARGET_USER"

###############################################
# Network Manager only
###############################################
INTERFACES_FILE="/etc/network/interfaces"

INTERFACES_CONTENT=$(cat << 'EOF'
auto lo
iface lo inet loopback
EOF
)

write_if_changed "$INTERFACES_FILE" "$INTERFACES_CONTENT"

systemctl enable NetworkManager
systemctl restart NetworkManager

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
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' /etc/default/grub

update-grub

###############################################
# Locale
###############################################
grep -q "^it_IT.UTF-8 UTF-8" /etc/locale.gen || \
  printf "it_IT.UTF-8 UTF-8\n" >> /etc/locale.gen

locale-gen

update-locale \
LANG=en_US.UTF-8 \
LANGUAGE=en_US:en \
LC_CTYPE="en_US.UTF-8" \
LC_NUMERIC=it_IT.UTF-8 \
LC_TIME=it_IT.UTF-8 \
LC_COLLATE="en_US.UTF-8" \
LC_MONETARY=it_IT.UTF-8 \
LC_MESSAGES="en_US.UTF-8" \
LC_PAPER=it_IT.UTF-8 \
LC_NAME=it_IT.UTF-8 \
LC_ADDRESS=it_IT.UTF-8 \
LC_TELEPHONE=it_IT.UTF-8 \
LC_MEASUREMENT=it_IT.UTF-8

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
    bash "$SCRIPT_DIR/hard_deb.sh"
  fi
fi

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

###############################################
# Testing safety net (installed last on purpose)
###############################################
# apt-listbugs warns before installing packages with serious known bugs,
# apt-listchanges shows what changed. Installed at the end so the hooks do
# not interrupt this non-interactive script.
apt-get install -y apt-listbugs apt-listchanges

###############################################
# Summary
###############################################
echo "System installation completed."

if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo
    echo "Packages not available in testing and skipped:"
    printf '  - %s\n' "${SKIPPED[@]}"
fi

###############################################
# User session script
###############################################
USER_SCRIPT="$GIT_DIR/user_customization.sh"

if [ -f "$USER_SCRIPT" ]; then
    echo "Running user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE="$DESKTOP_CHOICE" bash "$USER_SCRIPT"
fi
