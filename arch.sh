#kde
pacman -S --needed plasma plasma-wayland-session plasma-wayland-protocols sddm ark dolphin konsole okular galculator kate spectacle packagekit-qt5 print-manager system-config-printer ksystemlog partitionmanager kamoso gwenview --noconfirm

#remove components
pacman -Rd --nodeps bluez plasma-browser-integration --noconfirm

#sddm
systemctl enable sddm

#utilities
pacman -S --needed papirus-icon-theme htop curl neofetch rust wget linux-headers bash-completion sof-firmware appstream mlocate unrar unzip p7zip fuse ffmpeg pipewire pipewire-alsa pipewire-jack pipewire-pulse --noconfirm

#fonts
pacman -S --needed ttf-ubuntu-font-family ttf-opensans ttf-carlito ttf-caladea ttf-liberation ttf-inconsolata ttf-fira-code ttf-fira-mono ttf-fira-sans --noconfirm

#applications
pacman -S --needed firefox chromium vim nano vlc gimp transmission-qt --noconfirm

#network
pacman -S --needed network-manager-applet nss-mdns inetutils net-tools avahi --noconfirm
systemctl enable avahi-daemon
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf

#virt manager
pacman -S --needed virt-manager libvirt iptables-nft qemu dnsmasq --noconfirm
systemctl enable libvirtd
usermod -aG libvirt fabri

#firewall
pacman -S ufw --noconfirm
systemctl enable ufw
sed -i 's/ENABLED=no/ENABLED=yes/g' /etc/ufw/ufw.conf
ufw allow mdns

#printing and scanning
pacman -S --needed sane cups gutenprint simple-scan --noconfirm
systemctl enable cups
sed -i 's/resolve/mdns_minimal [NOTFOUND=return] resolve/g' /etc/nsswitch.conf
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

#grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg