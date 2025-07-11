# install applications
apt install vlc ubuntu-restricted-extras gnome-shell-extension-manager gnome-weather gnome-calendar gnome-clocks gnome-tweaks ffmpegthumbnailer timeshift fastfetch curl wget htop net-tools apt-transport-https vim shotwell transmission dracut-core apt-show-versions debsums distrobox -y

# fonts & icons
apt install fonts-crosextra-carlito fonts-crosextra-caladea -y

# cockpit
apt install cockpit cockpit-podman cockpit-machines pcp cockpit-sosreport virt-viewer -y
adduser fabri libvirt
virsh net-autostart default
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y

# code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
apt update && apt install code -y

# onlyoffice
wget https://github.com/ONLYOFFICE/DesktopEditors/releases/latest/download/onlyoffice-desktopeditors_amd64.deb
apt install -f ./onlyoffice-desktopeditors_amd64.deb -y

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

# lid setting
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g' /etc/systemd/logind.conf

