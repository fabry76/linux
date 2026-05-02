set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

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
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

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

# Chrome
wget -qO /etc/apt/keyrings/google-chrome.asc \
  https://dl.google.com/linux/linux_signing_key.pub
chmod 644 /etc/apt/keyrings/google-chrome.asc

write_if_changed /etc/apt/sources.list.d/google-chrome.sources "$(cat << 'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.asc
EOF
)"

# VSCode
wget -qO /etc/apt/keyrings/vscode.asc \
  https://packages.microsoft.com/keys/microsoft.asc
chmod 644 /etc/apt/keyrings/vscode.asc

write_if_changed /etc/apt/sources.list.d/vscode.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/vscode.asc
Architectures: amd64 arm64 armhf
EOF
)"

###############################################
# Update Repositories
###############################################
apt-get update

###############################################
# Initial Firmware, Drivers and Utilities
###############################################
apt-get install -y firmware-linux firmware-sof-signed firmware-realtek intel-media-va-driver-non-free

###############################################
# KDE Desktop
###############################################
apt-get install -y \
  kde-plasma-desktop \
  konsole \
  firefox-esr \
  plasma-browser-integration- \
  konqueror- \
  kdeconnect- \
  gnome-keyring- \
  evolution-data-server-common-

apt-get install -y ark kalk ksystemlog isoimagewriter ktorrent kolourpaint gwenview okular okular-extra-backends kcharselect kcolorchooser filelight plasma-widgets-addons krecorder plasma-workspace-wallpapers

###############################################
# KDE Flatpak
###############################################
apt-get install -y flatpak plasma-discover-backend-flatpak xdg-desktop-portal-kde kde-config-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --system flathub org.onlyoffice.desktopeditors org.gtk.Gtk3theme.Breeze-Dark
flatpak override org.onlyoffice.desktopeditors --env=GTK_USE_PORTAL=1 --env=GTK_THEME=Breeze-Dark

###############################################flatpak
# Apps & Utilities
###############################################
apt-get install -y rclone timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes fwupd apt-show-versions debsums starship nvme-cli google-chrome-stable code

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
ufw allow mdns
if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
   sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
ufw status | grep -q "active" || ufw --force enable

###############################################
# Virtualization
###############################################
apt-get install -y virt-manager virt-viewer qemu-kvm
runuser -u "$TARGET_USER" -- bash -c "mkdir -p \"$TARGET_HOME/Virtual\""

###############################################
# Printing & Scanning
###############################################
apt-get install -y cups printer-driver-gutenprint printer-driver-cups-pdf print-manager skanpage
systemctl enable cups

###############################################
# Networking
###############################################
INTERFACES_FILE="/etc/network/interfaces"

INTERFACES_CONTENT=$(cat << 'EOF'
auto lo
iface lo inet loopback
EOF
)

write_if_changed "$INTERFACES_FILE" "$INTERFACES_CONTENT"

###############################################
# Fastgate SMB Mount
###############################################
apt-get install -y cifs-utils

MOUNT_POINT="$TARGET_HOME/Fastgate"
USER_ID=$(id -u "$TARGET_USER")
GROUP_ID=$(id -g "$TARGET_USER")
CIFS_LINE="//192.168.1.254/samba/usb1_1 $MOUNT_POINT cifs _netdev,x-systemd.automount,vers=1.0,user=admin,pass=admin,iocharset=utf8,uid=$USER_ID,gid=$GROUP_ID,file_mode=0755,dir_mode=0755,cache=loose,actimeo=30,nofail,soft 0 0"

runuser -u "$TARGET_USER" -- mkdir -p "$MOUNT_POINT"
grep -qxF "$CIFS_LINE" /etc/fstab || echo "$CIFS_LINE" >> /etc/fstab

###############################################
# GRUB
###############################################
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet loglevel=3"/' /etc/default/grub

###############################################
# Locale
###############################################
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen

###############################################
# User Config
###############################################
# Starship
runuser -u "$TARGET_USER" -- bash -c "grep -qF 'eval \"\$(starship init bash)\"' \"$TARGET_HOME/.bashrc\" || echo 'eval \"\$(starship init bash)\"' >> \"$TARGET_HOME/.bashrc\""
runuser -u "$TARGET_USER" -- bash -c "install -D \"$TARGET_HOME/Git/linux/etc/starship.toml\" \"$TARGET_HOME/.config/starship.toml\""
# Force KDE portal
runuser -u "$TARGET_USER" -- bash -c "mkdir -p \"$TARGET_HOME/.config/environment.d\" && echo \"GTK_USE_PORTAL=1\" > \"$TARGET_HOME/.config/environment.d/portal.conf\""
# MPV
runuser -u "$TARGET_USER" -- bash -c "install -D \"$TARGET_HOME/Git/linux/etc/mpv.conf\" \"$TARGET_HOME/.config/mpv/mpv.conf\""
# Desktop Icons
runuser -u "$TARGET_USER" -- bash -c "cp \"$TARGET_HOME/Git/linux/etc/computer.desktop\" \"$TARGET_HOME/Desktop/computer.desktop\""
runuser -u "$TARGET_USER" -- bash -c "cp \"$TARGET_HOME/Git/linux/etc/gdrive_sync.desktop\" \"$TARGET_HOME/Desktop/gdrive_sync.desktop\""

###############################################
# Finalization
###############################################
usermod -aG libvirt,kvm,lpadmin "$TARGET_USER"
plymouth-set-default-theme lines -R
update-grub
locale-gen
apt-get -y autoremove && apt-get clean
