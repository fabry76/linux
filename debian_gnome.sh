# update repositories
apt update && apt upgrade -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# firmware
apt install firmware-linux firmware-sof-signed firmware-realtek -y

# firefox
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
apt update && apt install firefox -y

# desktop environment
apt install gnome-core gnome-shell-extension-dashtodock gnome-weather gnome-calendar gnome-clocks gnome-tweaks file-roller seahorse transmission-gtk shotwell -y

# apps & utilities
apt install timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes apt-transport-https dracut-core fwupd apt-show-versions debsums distrobox -y

# multimedia
apt install ffmpeg ffmpegfs libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly vlc -y

# fonts & icons
apt install yaru-theme-gnome-shell yaru-theme-icon papirus-icon-theme ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea -y

# cockpit
apt install cockpit cockpit-podman cockpit-machines cockpit-sosreport -y
adduser fabri libvirt
virsh net-autostart default
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg
apt update && apt install code -y

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y

# onlyoffice
wget https://github.com/ONLYOFFICE/DesktopEditors/releases/latest/download/onlyoffice-desktopeditors_amd64.deb
apt install -f ./onlyoffice-desktopeditors_amd64.deb

# firewall
apt install gufw -y
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

# printing and scanning
apt install cups printer-driver-all printer-driver-cups-pdf sane-utils simple-scan -y
systemctl enable cups
adduser fabri lpadmin

# grub
sed -i 's/quiet/quiet loglevel=3 splash/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/g' /etc/default/grub
update-grub

# plymouth themes
plymouth-set-default-theme -R lines

# lid setting
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g' /etc/systemd/logind.conf

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END
