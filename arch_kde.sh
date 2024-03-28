# refresh mirrors
pacman -Syyu

# kde
pacman -S --needed plasma kwalletmanager plasma-wayland-protocols sddm ark dolphin konsole okular kalk kate spectacle packagekit-qt5 packagekit-qt6 libxvmc kdialog print-manager system-config-printer ksystemlog partitionmanager kamoso gwenview --noconfirm

# remove components
pacman -Rd --nodeps plasma-browser-integration --noconfirm

# sddm
systemctl enable sddm
echo "setxkbmap it" | sudo tee -a /usr/share/sddm/scripts/Xsetup

# audio
pacman -S --needed pipewire pipewire-audio pipewire-alsa pipewire-pulse wireplumber --noconfirm

# applications
pacman -S --needed firefox vim nano vlc gimp htop neofetch timeshift podman distrobox --noconfirm

# utilities
pacman -S --needed fuse-overlayfs speech-dispatcher curl neofetch rust wget bash-completion sof-firmware appstream mlocate unrar unzip p7zip fuse2 ffmpeg ffmpegthumbs --noconfirm

# fonts & icons
pacman -S --needed papirus-icon-theme ttf-ubuntu-font-family ttf-opensans ttf-carlito ttf-caladea ttf-liberation ttf-inconsolata ttf-fira-code ttf-fira-mono ttf-fira-sans --noconfirm

# network
pacman -S --needed network-manager-applet nss-mdns inetutils net-tools avahi --noconfirm
systemctl enable avahi-daemon

# virt manager
pacman -S --needed qemu virt-manager dnsmasq --noconfirm
systemctl enable libvirtd.socket
usermod -a -G libvirt fabri
sed -i 's/#user = "libvirt-qemu"/user = "fabri"/g' /etc/libvirt/qemu.conf
sed -i 's/#group = "libvirt-qemu"/group = "libvirt"/g' /etc/libvirt/qemu.conf

# firewall
pacman -S --needed ufw --noconfirm
systemctl enable ufw
ufw allow mdns

# printing and scanning
pacman -S --needed sane cups gutenprint --noconfirm
systemctl enable cups
sed -i 's/resolve/mdns_minimal [NOTFOUND=return] resolve/g' /etc/nsswitch.conf
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

# fastgate
pacman -S --needed cifs-utils samba smbclient --noconfirm
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END