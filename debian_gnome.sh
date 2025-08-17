# update repositories
apt update && apt upgrade -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# firmware
apt install firmware-linux firmware-sof-signed firmware-realtek -y

# de
apt install gnome-core showtime+ papers+ gnome-console+ firefox-esr+ network-manager+ --no-install-recommends -y

# de extra 
apt install gnome-themes-extra gnome-sound-recorder gnome-shell-extension-prefs gnome-shell-extension-dash-to-panel gnome-tweaks file-roller seahorse transmission-gtk -y

# apps & utilities
apt install snapd timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes apt-transport-https dracut-core apt-show-versions debsums -y

# multimedia
apt install ffmpeg ffmpegfs libavcodec-extra gstreamer1.0-vaapi gstreamer1.0-libav gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly -y

# fonts & icons
apt install papirus-icon-theme ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea -y

# virtual
apt install virt-manager virt-viewer -y
adduser fabri libvirt
virsh net-autostart default

# printing
apt install printer-driver-all printer-driver-cups-pdf -y
systemctl enable cups
adduser fabri lpadmin

# chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -f ./google-chrome-stable_current_amd64.deb -y

# firewall and network
apt install gufw avahi-daemon -y
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

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
apt install cifs-utils -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END
