# install applications
apt install ubuntu-restricted-extras intel-media-va-driver-non-free vlc ffmpeg ffmpegthumbnailer timeshift fastfetch curl htop net-tools apt-transport-https vim apt-show-versions fwupd transmission-qt kolourpaint kamoso okular kcolorchooser filelight kweather rclone filezilla -y

# snaps
snap install onlyoffice-desktopeditors
snap install --classic code

# virtual
apt install virt-manager virt-viewer -y
adduser fabri libvirt

# firewall
ufw enable
ufw allow mdns

# printing and scanning
apt install printer-driver-all printer-driver-cups-pdf sane skanpage -y
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
