# install applications
apt install ubuntu-restricted-extras gnome-shell-extension-manager gnome-weather gnome-calendar gnome-clocks gnome-tweaks vlc ffmpegthumbnailer timeshift neofetch curl wget htop net-tools apt-transport-https vim cheese shotwell transmission usb-creator-gtk -y

# fonts & icons
apt install fonts-crosextra-carlito fonts-crosextra-caladea -y

# snaps
snap install gimp onlyoffice-desktopeditors
snap install code --classic

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y
rm -f google-chrome-stable_current_amd64.deb

# firewall
ufw enable
ufw allow mdns

# printing and scanning
apt install sane printer-driver-all printer-driver-cups-pdf simple-scan -y
usermod -a -G lpadmin fabri
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END

# grub
sed -i 's/quiet/quiet loglevel=3/g' /etc/default/grub
tee -a /etc/default/grub << END
GRUB_RECORDFAIL_TIMEOUT=5
END
update-grub
