set -euo pipefail

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Variables
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_DIR="$(dirname "$SCRIPT_DIR")"

###############################################
# Functions
###############################################
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
    return 0
  fi

  printf "%s" "$content" > "$file"
}

###############################################
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

###############################################
# Initial selection
###############################################
while :; do
    read -rp "Mount Fastgate SMB share? (y/N): " RUN_FASTGATE
    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then

    CRED_FILE="/etc/samba/fastgate.creds"
    
    install -d -m 700 /etc/samba

    CRED_STATE="missing"

    if [ -f "$CRED_FILE" ]; then
        if grep -q "^username=" "$CRED_FILE" &&
           grep -q "^password=" "$CRED_FILE"; then
            CRED_STATE="valid"
        else
            CRED_STATE="invalid"
        fi
    fi

    if [ "$CRED_STATE" = "valid" ]; then
        echo
        echo "Fastgate credentials already exist."
        read -rp "Update credentials? (y/N): " CONFIRM

        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            CRED_STATE="update"
        fi
    fi

    if [ "$CRED_STATE" = "missing" ] ||
       [ "$CRED_STATE" = "invalid" ] ||
       [ "$CRED_STATE" = "update" ]; then

        echo
        echo "=== Fastgate credentials ==="

        read -rp "Username: " NAS_USER
        read -rsp "Password: " NAS_PASS
        echo

        umask 077

        cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

        chown root:root "$CRED_FILE"
        chmod 600 "$CRED_FILE"
    fi
fi

###############################################
# Install dependencies for key management
###############################################
apt-get install -y curl
install -d -m 0755 /etc/apt/keyrings

###############################################
# Update repositories
###############################################
apt-get update
apt-get -y upgrade

###############################################
# Base system & firmware
###############################################
apt-get install -y intel-media-va-driver-non-free nvme-cli

###############################################
# Desktop & GNOME utilities
###############################################
apt-get install -y \
  gnome-shell-extension-manager \
  gnome-weather \
  gnome-calendar \
  gnome-tweaks \
  gnome-snapshot \
  gnome-sound-recorder \
  gnome-boxes \
  showtime

###############################################
# Applications & Utilities
###############################################
apt-get install -y \
  vim \
  htop \
  fastfetch \
  curl \
  timeshift \
  apt-show-versions \
  rclone \
  unrar \
  starship \
  debsums

###############################################
# Other apps
###############################################
bash "$SCRIPT_DIR/vscode.sh"
bash "$SCRIPT_DIR/brave.sh"
#bash "$SCRIPT_DIR/chrome.sh"

###############################################
# Multimedia and Extra
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

apt-get install -y \
  ffmpeg \
  ffmpegthumbnailer \
  ubuntu-restricted-extras \
  fonts-firacode
  
###############################################
# Snaps
###############################################
snap install pinta onlyoffice-desktopeditors transmission

###############################################
# Firewall
###############################################
apt-get install -y gufw

ufw allow mdns
ufw --force enable

###############################################
# Printing & Scanning
###############################################
apt-get install -y \
  cups \
  printer-driver-all \
  printer-driver-cups-pdf \
  sane \
  simple-scan

usermod -aG lpadmin "$TARGET_USER"
systemctl enable cups

###############################################
# GRUB
###############################################
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub

sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"/' \
  /etc/default/grub

update-grub

###############################################
# Locale
###############################################
grep -q "^it_IT.UTF-8 UTF-8" /etc/locale.gen || \
  printf "it_IT.UTF-8 UTF-8\n" >> /etc/locale.gen

locale-gen

###############################################
# Fastgate
###############################################
if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    apt-get install -y cifs-utils
    bash "$GIT_DIR/fastgate.sh" "$TARGET_USER"
fi

###############################################
# Hardening
###############################################
write_if_changed /etc/modprobe.d/disable-protocols.conf "$(cat << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false

blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
EOF
)"

sysctl --system
echo
echo "Hardening completed."

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

echo
echo "Installation completed."

###############################################
# User session script
###############################################
runuser -u "$TARGET_USER" -- bash "$GIT_DIR/gnome_user.sh"