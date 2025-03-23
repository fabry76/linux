# refresh mirrors
pacman -Syyu

# kde
pacman -S --needed plasma kwalletmanager plasma-wayland-protocols sddm ark dolphin konsole okular kate kalk spectacle libxvmc kdialog print-manager system-config-printer ksystemlog partitionmanager kamoso gwenview power-profiles-daemon dmidecode geoclue2 kdegraphics-thumbnailers --noconfirm

# remove components
pacman -Rd --nodeps plasma-browser-integration --noconfirm

# sddm
systemctl enable sddm
echo "setxkbmap it" | sudo tee -a /usr/share/sddm/scripts/Xsetup

# audio
pacman -S --needed pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber --noconfirm

# applications
pacman -S --needed firefox chromium vim nano less htop fastfetch timeshift podman distrobox starship transmission-qt isoimagewriter vlc libreoffice-fresh gimp kolourpaint --noconfirm
systemctl enable cronie
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 fabri

# utilities
pacman -S --needed speech-dispatcher curl fastfetch rust wget bash-completion sof-firmware appstream plocate unrar unzip 7zip fuse2 ffmpeg ffmpegthumbs ffmpegthumbnailer gst-libav gst-plugins-ugly dnsutils whois --noconfirm

# fonts & icons
pacman -S --needed ttf-ubuntu-font-family ttf-opensans ttf-carlito ttf-caladea ttf-liberation ttf-inconsolata ttf-dejavu noto-fonts adobe-source-code-pro-fonts adobe-source-sans-fonts adobe-source-serif-fonts --noconfirm

# network
pacman -S --needed nss-mdns inetutils net-tools avahi --noconfirm
systemctl enable avahi-daemon
systemctl enable bluetooth.service

# flatpak
pacman -S --needed flatpak --noconfirm
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# cockpit
pacman -S --needed cockpit-machines cockpit-podman cockpit-packagekit cockpit-storaged cockpit-files qemu-base dnsmasq virt-viewer pcp virt-install --noconfirm
systemctl enable libvirtd.socket
systemctl enable cockpit.socket
usermod -a -G libvirt fabri
virsh net-autostart default
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# firewall
pacman -S --needed ufw --noconfirm
systemctl enable ufw.service
ufw enable
ufw allow mdns

# printing and scanning
pacman -S --needed sane skanlite cups cups-pdf --noconfirm
systemctl enable cups
sed -i 's/resolve/mdns_minimal [NOTFOUND=return] resolve/g' /etc/nsswitch.conf
sed -i 's+#Out /var/spool/cups-pdf/${USER}+Out /home/${USER}/Documents+g' /etc/cups/cups-pdf.conf

# fastgate
pacman -S --needed cifs-utils samba smbclient --noconfirm
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs _netdev,vers=1.0,user=admin,pass=admin,iocharset=utf8,file_mode=0777,dir_mode=0777,x-systemd.automount	0 0
END