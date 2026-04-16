# enable backports
tee /etc/apt/sources.list.d/debian-backports.sources << END
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
END
apt update && apt install -t trixie-backports linux-image-amd64 linux-headers-amd64 firmware-linux -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# firmware
apt install firmware-sof-signed firmware-realtek intel-media-va-driver-non-free -y

# desktop environment
apt install kde-plasma-desktop ark kalk kde-spectacle ksystemlog isoimagewriter transmission-qt kolourpaint gwenview okular kcharselect kcolorchooser filelight kweather plasma-widgets-addons -y

# apps & utilities
apt install rclone timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes fwupd apt-show-versions debsums filezilla -y

# multimedia
apt install mpv ffmpeg libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly -y

# fonts & icons
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt install ttf-mscorefonts-installer papirus-icon-theme fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea -y

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install ./google-chrome-stable_current_amd64.deb -y
rm google-chrome-stable_current_amd64.deb

# vscode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/vscode.gpg
tee /etc/apt/sources.list.d/vscode.sources << END
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/vscode.gpg
Architectures: amd64 arm64 armhf
END
apt update && apt install code -y

# onlyoffice
mkdir -p -m 700 ~/.gnupg
gpg --no-default-keyring --keyring gnupg-ring:/tmp/onlyoffice.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5
chmod 644 /tmp/onlyoffice.gpg
chown root:root /tmp/onlyoffice.gpg
mv /tmp/onlyoffice.gpg /usr/share/keyrings/onlyoffice.gpg
echo 'deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main' | sudo tee -a /etc/apt/sources.list.d/onlyoffice.list
apt update && apt install onlyoffice-desktopeditors -y   

# flatpak
apt install flatpak plasma-discover-backend-flatpak -y
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# virtual
apt install virt-manager virt-viewer qemu-system -y

# printing and scanning
apt install cups printer-driver-gutenprint printer-driver-cups-pdf print-manager skanpage -y
systemctl enable cups

# firewall
apt install ufw -y
sed -i 's/^managed=false/managed=true/' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

# grub
sed -i 's/quiet/quiet loglevel=3 splash/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/g' /etc/default/grub
update-grub

# plymouth themes
plymouth-set-default-theme -R lines

# starship
curl -sS https://starship.rs/install.sh | sh -s -- -y
runuser -u fabri -- sh -c 'echo "eval \"\$(starship init bash)\"" >> /home/fabri/.bashrc'
runuser -u fabri -- sh -c 'cp /home/fabri/Git/linux/etc/starship.toml /home/fabri/.config'

# fastgate
apt install cifs-utils -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs _netdev,vers=1.0,user=admin,pass=admin,iocharset=utf8,file_mode=0777,dir_mode=0777,x-systemd.automount	0 0
END

# varie
apt-file update
usermod -aG libvirt,kvm,lpadmin fabri
runuser -u fabri -- sh -c 'install -D /home/fabri/Git/linux/etc/mpv.conf /home/fabri/.config/mpv/mpv.conf'

# remove components
apt purge plasma-browser-integration konqueror zutty -y
apt autoremove -y
