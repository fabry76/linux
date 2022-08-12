# dnf
tee -a /etc/dnf/dnf.conf << END
max_parallel_downloads=10
fastestmirror=True
END

# update
dnf update -y

# rpm fusion
dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y

dnf install \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

# media codecs
dnf install gstreamer1-plugins-{bad-\*,good-\*,base} gstreamer1-plugin-openh264 gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel -y
dnf install lame\* --exclude=lame-devel -y
dnf group upgrade --with-optional Multimedia -y

# install packages
dnf install google-chrome-stable gimp neofetch htop shotwell vim gnome-tweaks transmission gnome-extensions-app vlc unrar -y

# fonts & icons
dnf install papirus-icon-theme cabextract xorg-x11-font-utils -y
sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

# flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# vscode
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
dnf update -y
dnf install code -y

# firewall
dnf install firewall-config -y
cp /home/fabri/Git/linux/conf/FedoraFW.xml /usr/lib/firewalld/zones
firewall-cmd --reload
firewall-cmd --set-default-zone FedoraFW

# virt manager
#dnf install virt-manager -y

# printing and scanning
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf