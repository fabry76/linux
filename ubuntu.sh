set -euo pipefail

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Target User & Home
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

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
# Extra Repositories
###############################################
# Folder
install -d -m 0755 /etc/apt/keyrings

# Brave
curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
  -o /etc/apt/keyrings/brave-browser-archive-keyring.gpg

chmod 644 /etc/apt/keyrings/brave-browser-archive-keyring.gpg

write_if_changed /etc/apt/sources.list.d/brave-browser.sources "$(cat << 'EOF'
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/brave-browser-archive-keyring.gpg
EOF
)"

# VSCode
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
gpg --dearmor -o /etc/apt/keyrings/microsoft-vscode.gpg

chmod 644 /etc/apt/keyrings/microsoft-vscode.gpg

write_if_changed /etc/apt/sources.list.d/vscode.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/microsoft-vscode.gpg
EOF
)"

###############################################
# Update repositories
###############################################
apt-get update

###############################################
# Base system & firmware
###############################################
apt-get install -y intel-media-va-driver-non-free nvme-cli

###############################################
# Desktop & GNOME utilities
###############################################
apt-get install -y \
  gnome-shell-extension-manager \
  gnome-weather \
  gnome-calendar \
  gnome-tweaks \
  gnome-snapshot \
  gnome-sound-recorder \
  gnome-boxes \
  seahorse \
  showtime

###############################################
# Applications & Utilities
###############################################
apt-get install -y \
  brave-browser \
  code \
  vim \
  htop \
  fastfetch \
  curl \
  timeshift \
  apt-show-versions \
  rclone \
  unrar \
  starship \
  debsums

###############################################
# Multimedia and Extra
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

apt-get install -y \
  ffmpeg \
  ffmpegthumbnailer \
  ubuntu-restricted-extras \
  fonts-firacode
  
###############################################
# Snaps
###############################################
snap install -y pinta onlyoffice-desktopeditors transmission

###############################################
# Firewall
###############################################
apt-get install -y ufw

ufw --force enable
ufw allow mdns

###############################################
# Printing & Scanning
###############################################
apt-get install -y \
  cups \
  printer-driver-all \
  printer-driver-cups-pdf \
  sane \
  simple-scan

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
# Finalization
###############################################
runuser -u "$TARGET_USER" -- bash -c "grep -qF 'eval \"\$(starship init bash)\"' \"$TARGET_HOME/.bashrc\" || echo 'eval \"\$(starship init bash)\"' >> \"$TARGET_HOME/.bashrc\""
runuser -u "$TARGET_USER" -- bash -c "install -D \"$TARGET_HOME/Git/linux/etc/starship.toml\" \"$TARGET_HOME/.config/starship.toml\""

###############################################
# Optional Fastgate setup
###############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/2_fastgate.sh" ]; then
  echo
  read -rp "Mount Fastgate now? (y/N): " RUN_FASTGATE

  if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/2_fastgate.sh"
  fi
fi

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

echo
echo "Installation completed."