###############################################
# Initial
###############################################
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get install -y gnupg ca-certificates wget

###############################################
# Variables
###############################################
TARGET_USER="${SUDO_USER:-${LOGNAME:-$(whoami)}}"
TARGET_HOME=$(eval echo "~$TARGET_USER")
MOUNT_POINT="$TARGET_HOME/Fastgate"

###############################################
# Functions
###############################################
# write idempotent function
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ ! -f "$file" ] || ! diff -q <(printf "%s" "$content") "$file" >/dev/null 2>&1; then
    printf "%s" "$content" > "$file"
  fi
}

###############################################
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install-full.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

###############################################
# Enable contrib + non-free
###############################################
if [ -f /etc/apt/sources.list ]; then
  sed -i '/^deb / {
    s/ main\(.*\)$/ main contrib non-free non-free-firmware/
  }' /etc/apt/sources.list
  sed -i '/^deb-src / {
    s/ main\(.*\)$/ main contrib non-free non-free-firmware/
  }' /etc/apt/sources.list
fi
# Support format .sources (if exists)
for f in /etc/apt/sources.list.d/*.sources; do
  [ -f "$f" ] || continue
  sed -i 's/^Components:.*/Components: main contrib non-free non-free-firmware/' "$f"
done

###############################################
# Extra Repositories
###############################################
# Folder
install -d -m 0755 /etc/apt/keyrings
# Chrome
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /etc/apt/keyrings/google-chrome.gpg
chmod 644 /etc/apt/keyrings/google-chrome.gpg
write_if_changed /etc/apt/sources.list.d/google-chrome.sources "$(cat << 'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.gpg
EOF
)"
# Firefox
wget -qO /etc/apt/keyrings/mozilla.gpg https://packages.mozilla.org/apt/repo-signing-key.gpg
chmod 644 /etc/apt/keyrings/mozilla.gpg
write_if_changed /etc/apt/sources.list.d/mozilla.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/mozilla.gpg
EOF
)"
# VSCode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/keyrings/vscode.gpg
chmod 644 /etc/apt/keyrings/vscode.gpg
write_if_changed /etc/apt/sources.list.d/vscode.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/vscode.gpg
Architectures: amd64 arm64 armhf
EOF
)"

apt-get update

###############################################
# Locale
###############################################
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

###############################################
# Firmware & Drivers
###############################################
apt-get install -y firmware-linux firmware-sof-signed firmware-realtek intel-media-va-driver-non-free

###############################################
# KDE Desktop
###############################################
apt-get install -y kde-plasma-desktop plasma-browser-integration-
apt-get install -y ark kalk ksystemlog isoimagewriter ktorrent kolourpaint gwenview okular okular-extra-backends kcharselect kcolorchooser filelight kweather plasma-widgets-addons krecorder plasma-workspace-wallpapers

###############################################
# Firewall
###############################################
apt-get install -y ufw
ufw allow mdns
if grep -q "managed=false" /etc/NetworkManager/NetworkManager.conf; then
   sed -i 's/managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
fi
ufw status | grep -q "Status: active" || ufw --force enable

###############################################
# Apps & Utilities
###############################################
apt-get install -y rclone timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes fwupd apt-show-versions debsums filezilla starship nvme-cli google-chrome-stable firefox code

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
# Flatpak
###############################################
apt-get install -y flatpak plasma-discover-backend-flatpak xdg-desktop-portal-kde kde-config-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --system flathub org.onlyoffice.desktopeditors org.gtk.Gtk3theme.Breeze
flatpak override org.onlyoffice.desktopeditors --env=GTK_THEME=Breeze --env=GTK_USE_PORTAL=1

###############################################
# Virtualization
###############################################
apt-get install -y virt-manager virt-viewer qemu-kvm

###############################################
# Printing & Scanning
###############################################
apt-get install -y cups printer-driver-gutenprint printer-driver-cups-pdf print-manager skanpage

###############################################
# Fastgate SMB Mount
###############################################
apt-get install -y cifs-utils

runuser -u "$TARGET_USER" -- mkdir -p "$MOUNT_POINT"
CIFS_LINE="//192.168.1.254/samba/usb1_1 $MOUNT_POINT cifs _netdev,vers=1.0,user=admin,pass=admin,iocharset=utf8,file_mode=0777,dir_mode=0777,x-systemd.automount   0 0"
grep -qxF "$CIFS_LINE" /etc/fstab || echo "$CIFS_LINE" >> /etc/fstab

###############################################
# GRUB
###############################################
if ! grep -q "loglevel=3" /etc/default/grub; then
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&loglevel=3 splash /' /etc/default/grub
fi
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
update-grub

###############################################
# User Config
###############################################
# Starship
runuser -u "$TARGET_USER" -- bash -c "grep -qF 'eval \"\$(starship init bash)\"' \"$TARGET_HOME/.bashrc\" || echo 'eval \"\$(starship init bash)\"' >> \"$TARGET_HOME/.bashrc\""
runuser -u "$TARGET_USER" -- bash -c "install -D \"$TARGET_HOME/Git/linux/etc/starship.toml\" \"$TARGET_HOME/.config/starship.toml\""
# MPV
runuser -u "$TARGET_USER" -- bash -c "install -D \"$TARGET_HOME/Git/linux/etc/mpv.conf\" \"$TARGET_HOME/.config/mpv/mpv.conf\""
# Force KDE portal
runuser -u "$TARGET_USER" -- bash -c "mkdir -p \"$TARGET_HOME/.config/environment.d\" && echo \"GTK_USE_PORTAL=1\" > \"$TARGET_HOME/.config/environment.d/portal.conf\""

###############################################
# Misc
###############################################
usermod -aG libvirt,kvm,lpadmin "$TARGET_USER"
plymouth-set-default-theme lines -R
systemctl enable cups

###############################################
# Remove unwanted components
###############################################
apt-get purge -y konqueror zutty
apt-get autoremove -y && apt-get clean
