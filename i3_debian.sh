# update repositories
apt update && apt upgrade -y

# firmware
apt install firmware-linux firmware-sof-signed firmware-realtek -y

# desktop environment
apt install lxterminal i3 polybar picom slick-greeter thunar thunar-archive-plugin seahorse light xbindkeys gvfs-backends ffmpegthumbnailer tumbler tumbler-plugins-extra upower xss-lock lm-sensors gtk2-engines-pixbuf dbus-x11 rofi policykit-1-gnome mousetweaks -y

# apps & utilities
apt install tlp gimp vim htop neofetch timeshift unrar net-tools curl apt-transport-https apt-file mousepad redshift transmission-gtk nitrogen shotwell galculator firefox-esr plymouth-themes wmctrl libnotify-bin -y

# audio
apt install pulseaudio pavucontrol vlc ffmpeg ffmpegfs libavcodec-extra gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad gstreamer1.0-pulseaudio libcanberra-pulse volumeicon-alsa -y

# fonts & icons
apt install fonts-font-awesome ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea fonts-firacode papirus-icon-theme -y

# network
apt install network-manager-gnome avahi-daemon ufw -y
systemctl enable avahi-daemon
systemctl enable ufw --now
ufw enable
ufw allow mdns
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf

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
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /home/fabri
apt install /home/fabri/google-chrome-stable_current_amd64.deb -y
rm -f /home/fabri/google-chrome-stable_current_amd64.deb

# vscode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
apt update && apt install code -y

# flatpak
apt install flatpak -y
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub org.gtk.Gtk3theme.Adwaita-dark org.libreoffice.LibreOffice org.flameshot.Flameshot -y

# locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

# grub
sed -i 's/quiet/quiet loglevel=3 splash/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=2/g' /etc/default/grub
update-grub

# fastgate
apt install cifs-utils smbclient -y
tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END

# touchpad X11
tee -a /etc/X11/xorg.conf.d/90-touchpad.conf << END
Section "InputClass"
        Identifier "touchpad"
        MatchIsTouchpad "on"
        Driver "libinput"
        Option "Tapping" "on"
        Option "TappingButtonMap" "lrm"
        Option "NaturalScrolling" "on"
        Option "ScrollMethod" "twofinger"
EndSection
END

# intel graphics X11
tee -a /etc/X11/xorg.conf.d/20-intel-gpu.conf << END
Section "Device"
        Identifier  "Intel Graphics"
        Driver      "intel"
        Option      "TearFree"  "true"
        Option      "DRI"    "3"
EndSection
END

# picom
tee -a /etc/X11/xorg.conf << END
Section "Extensions"
        Option  "Composite" "true"
EndSection
END

# greeter
sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=slick-greeter/g' /etc/lightdm/lightdm.conf
sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
sed -i 's/#allow-user-switching=true/allow-user-switching=true/g' /etc/lightdm/lightdm.conf

tee -a /etc/lightdm/slick-greeter.conf << END
[Greeter]
background=/home/fabri/Git/linux/img/greeter.png
END

sed -i 's/ConditionUser=!root/ConditionUser=!lightdm/g' /usr/lib/systemd/user/pulseaudio.socket
sed -i 's/ConditionUser=!root/ConditionUser=!lightdm/g' /usr/lib/systemd/user/pulseaudio.service

# plymouth themes
plymouth-set-default-theme -R lines

# thumbler
sed -i '/MaxFileSize=/c\MaxFileSize=0' /etc/xdg/tumbler/tumbler.rc

# power management
tlp start

# dmenu
ln -s /var/lib/flatpak/exports/bin/org.libreoffice.LibreOffice /usr/bin/libreoffice

# swappiness
tee -a /etc/sysctl.conf  << END
vm.swappiness=10
END

# purge components
apt purge avahi-autoipd rxvt-unicode -y
apt autoremove -y


## Debian 11

# intel graphics kernel
echo "dev.i915.perf_stream_paranoid = 0" | tee /etc/sysctl.d/99-i915.conf

# network
sed -i 's/false/true/g' /etc/NetworkManager/NetworkManager.conf
sed -i 's/Before=network.target/Before=network-pre.target/g' /lib/systemd/system/ufw.service
sed -i 's/DefaultDependencies=no/Wants=network-pre.target/g' /lib/systemd/system/ufw.service

# audio
systemctl disable --global pipewire
sed -i 's/load-module module-suspend-on-idle/#load-module module-suspend-on-idle/g' /etc/pulse/default.pa
rm -rf /home/fabri/.config/pulse

# iwlwifi
tee -a /etc/modprobe.d/iwlwifi.conf  << END
options iwlwifi enable_ini=N
END
bluez