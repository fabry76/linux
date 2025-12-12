# purge apps
apt purge libreoffice* -y
apt autoremove -y

# update repositories
apt update && apt upgrade -y

# brave
#curl -fsS https://dl.brave.com/install.sh | sh

# install applications
apt install ubuntu-restricted-extras intel-media-va-driver-non-free timeshift curl htop vim fwupd code transmission gnome-calculator google-chrome-stable -y

# cockpit
apt install cockpit cockpit-machines -y
systemctl enable cockpit.socket

# flatpaks
#flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#flatpak install org.onlyoffice.desktopeditors -y

# printing and scanning
apt install printer-driver-all printer-driver-cups-pdf -y
adduser fabri lpadmin

# firewall
ufw enable
ufw allow mdns

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END

