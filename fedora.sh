dnf update -y

hostnamectl set-hostname FEDORA

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.mattjakeman.ExtensionManager -y

dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

dnf install vlc ffmpegthumbnailer google-chrome-stable fastfetch htop vim gnome-tweaks transmission unrar -y

dnf install papirus-icon-theme cabextract adw-gtk3-theme -y
rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf update -y
dnf install code -y

dnf install firewall-config -y
cp /home/fabri/Git/linux/etc/ffw.xml /usr/lib/firewalld/zones
firewall-cmd --reload
firewall-cmd --set-default-zone ffw

tee -a /etc/fstab  << END
# map fastgate usb storage
//192.168.1.254/samba/usb1_1 /home/fabri/Fastgate cifs user=admin,vers=1.0,dir_mode=0777,file_mode=0777,pass=admin
END

fwupdmgr refresh --force
fwupdmgr get-devices # Lists devices with available updates.
fwupdmgr get-updates # Fetches list of available updates.
fwupdmgr update -y