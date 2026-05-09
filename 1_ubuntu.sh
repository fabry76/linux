# install applications
apt install ubuntu-restricted-extras intel-media-va-driver-non-free showtime ffmpeg gnome-shell-extension-manager gnome-weather gnome-calendar gnome-tweaks gnome-snapshot gnome-sound-recorder gnome-boxes ffmpegthumbnailer timeshift fastfetch curl htop net-tools apt-transport-https vim apt-show-versions fwupd -y

# snaps
snap install pinta onlyoffice-desktopeditors transmission
snap install --classic code

# firewall
ufw enable
ufw allow mdns

# printing and scanning
apt install printer-driver-all printer-driver-cups-pdf sane simple-scan -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
