#add non free reps
sed -i 's/deb http://deb.debian.org/debian/ bullseye main/deb/http://deb.debian.org/debian/ bullseye main non-free contrib/g' /etc/apt/sources.list
sed -i 's/deb-src http://deb.debian.org/debian/ bullseye main/deb-src http://deb.debian.org/debian/ bullseye main non-free contrib/g' /etc/apt/sources.list

#install common app
apt install sane cups avahi-daemon printer-driver-all printer-driver-cups-pdf htop curl vim simple-scan tlp net-tools firewalld firewall-config neofetch papirus-icon-theme timeshift ttf-mscorefonts-installer firmware-sof-signed apt-transport-https firmware-realtek intel-microcode stacer make snapd -y

#add user to group
sudo usermod -a -G lpadmin fabri

#scanner
echo "bjnp://192.168.1.94" | tee -a /etc/sane.d/pixma.conf

#tlp
tlp start

#locale
sed -i 's/# it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

#services
systemctl disable bluetooth
systemctl enable cups
systemctl enable firewalld
systemctl enable avahi-daemon

#firewall
firewall-cmd --set-default-zone=home

#virtualbox
tee -a /etc/apt/sources.list  << END
deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian bullseye contrib
END
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | apt-key add -
apt update
apt install virtualbox-6.1 -y

#snap
snap install --classic code
snap install libreoffice

#chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P /home/fabri/Downloads
apt install /home/fabri/Downloads/google-chrome-stable_current_amd64.deb -y
rm /home/fabri/Downloads/*.deb