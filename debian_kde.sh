# update repositories
apt update && apt upgrade -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# firmware
apt install firmware-linux firmware-sof-signed firmware-realtek -y

# desktop environment
apt install kde-plasma-desktop ark kalk kde-spectacle ksystemlog isoimagewriter transmission-qt kolourpaint kamoso gwenview -y

# firefox
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
apt update && apt install firefox -y

# apps & utilities
apt install pkexec timeshift vim htop fastfetch unrar net-tools curl apt-file plymouth-themes dracut-core fwupd apt-show-versions debsums -y

# multimedia
apt install vlc vlc-plugin-pipewire vlc-plugin-base ffmpeg ffmpegfs libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly -y

# fonts & icons
apt install ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea -y

# virtual
apt install virt-manager virt-viewer -y
adduser fabri libvirt
virsh net-autostart default

# printing and scanning
apt install cups printer-driver-all printer-driver-cups-pdf print-manager skanpage -y
systemctl enable cups
adduser fabri lpadmin

# brave
curl -fsS https://dl.brave.com/install.sh | sh

# firewall
apt install ufw -y
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
ufw enable
ufw allow mdns

# grub
sed -i 's/quiet/quiet loglevel=3 splash/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/g' /etc/default/grub
update-grub

# plymouth themes
plymouth-set-default-theme -R lines

# fastgate
apt install cifs-utils -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs _netdev,vers=1.0,user=admin,pass=admin,iocharset=utf8,file_mode=0777,dir_mode=0777,x-systemd.automount	0 0
END

# remove components
apt purge plasma-browser-integration konqueror zutty -y
apt autoremove -y