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
apt install gnome-core gnome-shell-extension-dash-to-panel gnome-shell-extension-dashtodock gnome-weather gnome-calendar gnome-clocks gnome-tweaks file-roller seahorse transmission-gtk shotwell -y

# apps & utilities
apt install timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes apt-transport-https dracut-core fwupd apt-show-versions debsums -y

# multimedia
apt install ffmpeg ffmpegfs libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly -y

# fonts & icons
apt install yaru-theme-gnome-shell yaru-theme-icon papirus-icon-theme ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea -y

# cockpit
apt install cockpit cockpit-podman cockpit-machines cockpit-sosreport -y
adduser fabri libvirt
virsh net-autostart default
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# vcode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
apt update && apt install code -y

# chrome
curl -fSsL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor | sudo tee /usr/share/keyrings/google-chrome.gpg >> /dev/null
echo deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main | sudo tee /etc/apt/sources.list.d/google-chrome.list
apt update && apt install google-chrome-stable -y

# flatpak
apt install flatpak gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.onlyoffice.desktopeditors com.spotify.Client org.gimp.GIMP -y

# firewall
apt install gufw -y
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

# printing and scanning
apt install sane cups printer-driver-cups-pdf simple-scan -y
adduser fabri lpadmin

# grub
sed -i 's/quiet/quiet loglevel=3 splash/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/g' /etc/default/grub
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
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs _netdev,vers=1.0,user=admin,pass=admin,file_mode=0777,dir_mode=0777  0 0
END

# various
sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=30s/g' /etc/systemd/system.conf
sed -i 's/#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=30s/g' /etc/systemd/user.conf