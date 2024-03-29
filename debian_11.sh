# update repositories
apt update && apt upgrade -y

# firmware
apt install firmware-linux firmware-sof-signed firmware-realtek -y

# desktop environment
apt install gnome-core gnome-weather gnome-calendar gnome-clocks gnome-screenshot gnome-shell-extension-dash-to-panel gnome-tweaks file-roller transmission-gtk shotwell cheese -y

# apps & utilities
apt install tlp gimp vim htop neofetch timeshift unrar net-tools curl build-essential apt-transport-https apt-file -y

# libreoffice
# apt install libreoffice libreoffice-gnome libreoffice-style-breeze libreoffice-style-sifr -y

# multimedia
apt install vlc ffmpeg libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-ugly -y

# fonts & icons
apt install ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea fonts-firacode papirus-icon-theme -y

# network
apt install avahi-daemon ufw -y
systemctl enable avahi-daemon
systemctl enable ufw --now
ufw enable
ufw allow mdns
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
sed -i 's/Before=network.target/Before=network-pre.target/g' /lib/systemd/system/ufw.service
sed -i 's/DefaultDependencies=no/Wants=network-pre.target/g' /lib/systemd/system/ufw.service

# virt manager
apt install virt-manager -y
adduser fabri libvirt
virsh net-autostart default

# printing and scanning
apt install sane cups printer-driver-all printer-driver-cups-pdf simple-scan -y
systemctl enable cups
usermod -a -G lpadmin fabri
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

# google chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y
rm -f google-chrome-stable_current_amd64.deb

# vscode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
apt update && apt install code -y

# flatpak
apt install flatpak gnome-software-plugin-flatpak -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gtk.Gtk3theme.Adwaita-dark com.system76.Popsicle org.libreoffice.LibreOffice -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# grub
sed -i 's/quiet/quiet loglevel=3/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
update-grub

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin,noauto,x-systemd.automount,user 0 0
END

## optional
# purge components
apt purge bluez avahi-autoipd -y
apt autoremove -y

# disable pipewire
systemctl disable --global pipewire
rm -rf /home/fabri/.config/pulse

# swappiness
tee -a /etc/sysctl.conf  << END
vm.swappiness=10
END

# iwlwifi
tee -a /etc/modprobe.d/iwlwifi.conf  << END
options iwlwifi enable_ini=N
END

# various
tlp start