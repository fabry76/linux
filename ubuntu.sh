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
# Extra Repositories
###############################################
# Folder
install -d -m 0755 /etc/apt/keyrings

# Brave
wget -qO /etc/apt/keyrings/brave-browser-archive-keyring.gpg \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

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

apt-get update && apt-get install -y brave-browser

# install applications
apt-get install -y ubuntu-restricted-extras intel-media-va-driver-non-free showtime ffmpeg gnome-shell-extension-manager gnome-weather gnome-calendar gnome-tweaks gnome-snapshot gnome-sound-recorder gnome-boxes ffmpegthumbnailer timeshift fastfetch curl htop apt-transport-https vim apt-show-versions fwupd rclone -y

# snaps
snap install pinta onlyoffice-desktopeditors transmission
snap install --classic code

# firewall
ufw enable
ufw allow mdns

# printing and scanning
apt-get install -y printer-driver-all printer-driver-cups-pdf sane simple-scan

###############################################
# Locale
###############################################
grep -q "^it_IT.UTF-8 UTF-8" /etc/locale.gen || \
  printf "it_IT.UTF-8 UTF-8\n" >> /etc/locale.gen

locale-gen

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