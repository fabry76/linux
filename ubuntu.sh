# install applications
apt install ubuntu-restricted-extras showtime ffmpeg gnome-shell-extension-manager gnome-weather gnome-calendar gnome-tweaks gnome-snapshot ffmpegthumbnailer timeshift fastfetch curl htop net-tools apt-transport-https vim transmission dracut-core apt-show-versions debsums -y

# vlc vlc-plugin-pipewire 

# virtual
apt install virt-manager virt-viewer -y
adduser fabri libvirt
virsh net-autostart default

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y

# snaps
snap install --classic code
snap install pinta onlyoffice-desktopeditors

# firewall
ufw enable
ufw allow mdns

# printing and scanning
apt install printer-driver-all printer-driver-cups-pdf sane simple-scan -y
adduser fabri lpadmin

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# grub
sed -i 's/quiet/quiet loglevel=3/g' /etc/default/grub
tee -a /etc/default/grub << END
GRUB_RECORDFAIL_TIMEOUT=5
END
update-grub

# varie
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g' /etc/systemd/logind.conf
fc-cache -fv