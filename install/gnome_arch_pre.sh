#install applications
<<<<<<< HEAD
pacman -S --needed gnome-shell gdm gnome-control-center gnome-terminal gnome-software gnome-software-packagekit-plugin file-roller gedit nautilus gnome-tweaks nano firefox sane cups nss-mdns htop curl vim cheese gnome-calculator shotwell vlc gnome-screenshot gnome-logs tracker gnome-system-monitor evince transmission-gtk simple-scan libreoffice tlp net-tools chromium ufw fuse gutenprint neofetch rust wget virtualbox gnome-keyring linux-lts-headers xdg-user-dirs gnome-weather ttf-ubuntu-font-family papirus-icon-theme --noconfirm
=======
pacman -S --needed gnome-shell gdm gnome-control-center gnome-terminal gnome-software gnome-software-packagekit-plugin file-roller gedit nautilus gnome-tweaks firefox sane cups nss-mdns htop curl vim cheese gnome-calculator shotwell vlc gnome-screenshot gnome-logs tracker gnome-system-monitor evince transmission-gtk simple-scan libreoffice tlp net-tools chromium ufw fuse gutenprint neofetch rust wget virtualbox gnome-keyring linux-lts-headers xdg-user-dirs gnome-weather ttf-ubuntu-font-family papirus-icon-theme --noconfirm
>>>>>>> 09b2ffbf648766fa49b0a6c84066f7370e6044ee

#scanner resolution
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

#printer resolution
sed -i 's/resolve/mdns_minimal [NOTFOUND=return] resolve/g' /etc/nsswitch.conf

#ufw
ufw enable

#tlp
tlp start

#services
systemctl disable bluetooth
systemctl disable iptables
systemctl enable gdm
systemctl enable avahi-daemon
systemctl enable cups
systemctl enable ufw

#setting permission to home folder
chown -R fabri:fabri /home/fabri/
