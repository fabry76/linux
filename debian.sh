#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

TARGET_USER="${SUDO_USER:-${LOGNAME:-$(whoami)}}"
HOME_DIR=$(eval echo "~$TARGET_USER")

###############################################
# 1. Enable backports
###############################################
tee /etc/apt/sources.list.d/debian-backports.sources << END
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
END

apt update
apt install -y -t trixie-backports linux-image-amd64 linux-headers-amd64 firmware-linux firmware-sof-signed firmware-realtek intel-media-va-driver-non-free

###############################################
# 2. Locale
###############################################
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

###############################################
# 3. BLOCK FIREFOX-ESR
###############################################
tee /etc/apt/preferences.d/no-firefox-esr << 'EOF'
Package: firefox-esr
Pin: release *
Pin-Priority: -1
EOF

###############################################
# 4. KDE Desktop
###############################################
apt install -y kde-plasma-desktop ark kalk kde-spectacle ksystemlog isoimagewriter transmission-qt kolourpaint gwenview okular kcharselect kcolorchooser filelight kweather plasma-widgets-addons

###############################################
# 5. Apps & Utilities
###############################################
apt install -y rclone timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes fwupd apt-show-versions debsums filezilla starship

###############################################
# 6. Multimedia
###############################################
apt install -y mpv ffmpeg libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-{base,good,bad,ugly}

###############################################
# 7. Fonts & Icons
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install -y ttf-mscorefonts-installer papirus-icon-theme fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea

###############################################
# 8. Google Chrome
###############################################
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt install -y ./google-chrome-stable_current_amd64.deb
  rm -f google-chrome-stable_current_amd64.deb
fi

###############################################
# 9. Firefox (Mozilla official repo)
###############################################
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/mozilla.gpg https://packages.mozilla.org/apt/repo-signing-key.gpg
chmod 644 /etc/apt/keyrings/mozilla.gpg

tee /etc/apt/sources.list.d/mozilla.sources << 'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/mozilla.gpg
EOF

apt update
apt install -y firefox

###############################################
# 10. VSCode
###############################################
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg

tee /etc/apt/sources.list.d/vscode.sources << END
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/vscode.gpg
Architectures: amd64 arm64 armhf
END

apt update
apt install -y code

###############################################
# 11. ONLYOFFICE
###############################################
mkdir -p /usr/share/keyrings
curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --dearmor -o /usr/share/keyrings/onlyoffice.gpg
chmod 644 /usr/share/keyrings/onlyoffice.gpg

tee /etc/apt/sources.list.d/onlyoffice.sources << END
Types: deb
URIs: https://download.onlyoffice.com/repo/debian
Suites: squeeze
Components: main
Signed-By: /usr/share/keyrings/onlyoffice.gpg
END

apt update
apt install -y onlyoffice-desktopeditors

###############################################
# 12. Flatpak
###############################################
apt install -y flatpak plasma-discover-backend-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

###############################################
# 13. Virtualization
###############################################
apt install -y virt-manager virt-viewer qemu-system

###############################################
# 14. Printing & Scanning
###############################################
apt install -y cups printer-driver-gutenprint printer-driver-cups-pdf print-manager skanpage
systemctl enable cups

###############################################
# 15. Firewall
###############################################
apt install -y ufw
sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

###############################################
# 16. Fastgate CIFS
###############################################
apt install -y cifs-utils

tee -a /etc/fstab << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs _netdev,vers=1.0,user=admin,pass=admin,iocharset=utf8,file_mode=0777,dir_mode=0777,x-systemd.automount 0 0
END

###############################################
# 17. GRUB
###############################################
if ! grep -q "loglevel=3" /etc/default/grub; then
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&loglevel=3 splash /' /etc/default/grub
fi
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub

update-grub

###############################################
# 18. Config
###############################################
runuser -u "$TARGET_USER" -- sh -c 'grep -qxF "eval \"\$(starship init bash)\"" "$HOME/.bashrc" || echo "eval \"\$(starship init bash)\"" >> "$HOME/.bashrc"'
runuser -u "$TARGET_USER" -- sh -c 'cp "$HOME/Git/linux/etc/starship.toml" "$HOME/.config"'
runuser -u "$TARGET_USER" -- sh -c 'install -D "$HOME/Git/linux/etc/mpv.conf" "$HOME/.config/mpv/mpv.conf"'

###############################################
# 20. Misc
###############################################
apt-file update || true
usermod -aG libvirt,kvm,lpadmin "$TARGET_USER"
plymouth-set-default-theme lines -R || true

###############################################
# 21. Remove unwanted components
###############################################
apt purge -y plasma-browser-integration konqueror zutty
apt autoremove -y
