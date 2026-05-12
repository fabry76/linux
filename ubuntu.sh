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

  if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
    printf "%s\n" "$content" > "$file"
  fi
}

###############################################
# Base system & firmware
###############################################
apt-get install -y \
  ubuntu-restricted-extras \
  linux-firmware \
  intel-media-va-driver-non-free \
  firmware-sof-signed \
  thermald \
  fwupd \
  nvme-cli

###############################################
# Extra repositories
###############################################
install -d -m 0755 /etc/apt/keyrings

# Brave
curl -fsSLo /etc/apt/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

chmod 644 /etc/apt/keyrings/brave-browser-archive-keyring.gpg

write_if_changed /etc/apt/sources.list.d/brave-browser.sources "$(cat << 'EOF'
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/brave-browser-archive-keyring.gpg
EOF
)"

###############################################
# VS Code repository
###############################################
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
  gpg --dearmor > /etc/apt/keyrings/packages.microsoft.gpg

chmod 644 /etc/apt/keyrings/packages.microsoft.gpg

write_if_changed /etc/apt/sources.list.d/vscode.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/packages.microsoft.gpg
EOF
)"

###############################################
# Update repositories
###############################################
apt-get update

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
  wget \
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
  ubuntu-restricted-extras
  
###############################################
# Snaps
###############################################
snap install pinta onlyoffice-desktopeditors transmission

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

###############################################
# Finalization
###############################################
systemctl enable thermald

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