dnf install -y cockpit-machines qemu-kvm libvirt virt-install virt-viewer
systemctl enable cockpit.socket
systemctl enable libvirtd