# purge apps
apt purge libreoffice* -y
apt autoremove -y

# install applications
apt install ubuntu-restricted-extras intel-media-va-driver-non-free htop vim filezilla rclone -y

# printing and scanning
apt install printer-driver-all printer-driver-cups-pdf -y
adduser fabri lpadmin

# virtual
apt install virt-manager virt-viewer -y
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "kvm"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# flatpak
flatpak install org.onlyoffice.desktopeditors -y

# firewall
ufw enable
ufw allow mdns

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END
