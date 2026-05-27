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
# Install dependencies for key management
###############################################
apt-get install -y gpg curl

###############################################
# Debian Repositories
###############################################
# Disable legacy sources.list
if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
  fi
fi

# Detect Debian codename
DEBIAN_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
DEBIAN_SOURCES="/etc/apt/sources.list.d/debian.sources"

write_if_changed "$DEBIAN_SOURCES" "$(cat << EOF
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: $DEBIAN_CODENAME
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security/
Suites: $DEBIAN_CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: $DEBIAN_CODENAME-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
)"

###############################################
# Extra Repositories
###############################################
# Folder
install -d -m 0755 /etc/apt/keyrings

# Brave
TMP_BRAVE_KEY="$(mktemp)"

curl -fsSL \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
  -o "$TMP_BRAVE_KEY"

if [ ! -f /etc/apt/keyrings/brave-browser-archive-keyring.gpg ] || \
   ! cmp -s "$TMP_BRAVE_KEY" /etc/apt/keyrings/brave-browser-archive-keyring.gpg; then
  install -m 0644 "$TMP_BRAVE_KEY" /etc/apt/keyrings/brave-browser-archive-keyring.gpg
fi

rm -f "$TMP_BRAVE_KEY"

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
TMP_VSCODE_KEY="$(mktemp)"

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
gpg --batch --yes --dearmor --output "$TMP_VSCODE_KEY"

if [ ! -f /etc/apt/keyrings/microsoft-vscode.gpg ] || \
   ! cmp -s "$TMP_VSCODE_KEY" /etc/apt/keyrings/microsoft-vscode.gpg; then
  install -m 0644 "$TMP_VSCODE_KEY" /etc/apt/keyrings/microsoft-vscode.gpg
fi

rm -f "$TMP_VSCODE_KEY"

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
# Update Repositories
###############################################
apt-get update

###############################################
# Initial Firmware, Drivers and Utilities
###############################################
apt-get install -y firmware-misc-nonfree linux-headers-amd64 firmware-sof-signed firmware-realtek intel-media-va-driver-non-free

###############################################
# KDE Plasma
###############################################
###############################################
# KDE Plasma
###############################################
apt-mark hold plasma-browser-integration

apt-get install -y kde-plasma-desktop konsole ark kalk isoimagewriter kolourpaint gwenview okular okular-extra-backends kcharselect kcolorchooser filelight plasma-widgets-addons krecorder plasma-workspace-wallpapers

###############################################
# KDE Flatpak
###############################################
apt-get install -y flatpak plasma-discover-backend-flatpak xdg-desktop-portal-kde kde-config-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --system flathub org.onlyoffice.desktopeditors org.mozilla.firefox org.gtk.Gtk3theme.Breeze org.kde.ktorrent
runuser -u "$TARGET_USER" -- bash -c "flatpak override --user org.onlyoffice.desktopeditors --env=GTK_USE_PORTAL=1 --env=GTK_THEME=Breeze:dark"
runuser -u "$TARGET_USER" -- bash -c "flatpak override --user org.mozilla.firefox --nofilesystem=host --filesystem=xdg-download --nodevice=all --nosocket=x11"
runuser -u "$TARGET_USER" -- bash -c 'flatpak override --user org.kde.ktorrent --nofilesystem=host --filesystem=xdg-download'

###############################################
# Apps & Utilities
###############################################
apt-get install -y timeshift vim htop fastfetch unrar plymouth-themes fwupd debsums starship nvme-cli brave-browser code rclone inotify-tools libnotify-bin thermald unattended-upgrades

###############################################
# Multimedia
###############################################
apt-get install -y mpv ffmpeg gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-{bad,ugly}

###############################################
# Fonts & Icons
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install -y ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea
apt-get install -y papirus-icon-theme

###############################################
# Firewall
###############################################
apt-get install -y ufw
if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
   sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
ufw allow mdns
ufw --force enable

###############################################
# Virtualization
###############################################
apt-get install -y virt-manager virt-viewer qemu-kvm

###############################################
# Printing & Scanning
###############################################
apt-get install -y cups printer-driver-gutenprint printer-driver-cups-pdf print-manager skanpage
systemctl enable cups

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

###############################################
# GRUB
###############################################
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' /etc/default/grub

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
usermod -aG libvirt,kvm,lpadmin "$TARGET_USER"
systemctl enable thermald
plymouth-set-default-theme lines -R
update-grub

###############################################
# Hardening
###############################################
# Kernel
write_if_changed /etc/sysctl.d/99-hardening.conf "$(cat << 'EOF'
kernel.kptr_restrict = 2
kernel.sysrq = 0
kernel.dmesg_restrict = 1
kernel.kexec_load_disabled = 1
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1

net.core.bpf_jit_harden = 2

net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
fs.suid_dumpable = 0
EOF
)"

# sysctl
sysctl --system

# Disable legacy network protocols
write_if_changed /etc/modprobe.d/disable-protocols.conf "$(cat << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false

blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
EOF
)"

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