set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

###############################################
# Root check
###############################################
if [ "$EUID" -ne 0 ]; then
  echo "Run as root (sudo)"
  exit 1
fi

###############################################
# Optional components selection
###############################################
while :; do
    echo "Which desktop environment do you want to install?"
    echo "1) KDE"
    echo "2) GNOME"
    read -rp "Choice [1-2]: " DESKTOP_CHOICE

    [[ "$DESKTOP_CHOICE" =~ ^[12]$ ]] && break

    echo "Please enter 1 for KDE or 2 for GNOME."
    echo
done

echo
while :; do
    echo "Which browsers do you want to install?"
    echo "1) Brave"
    echo "2) Chrome"
    echo "3) Firefox"
    echo
    echo "Examples:"
    echo "  1"
    echo "  1,3"
    echo "  1,2,3"
    read -rp "Selection: " BROWSER_SELECTION

    VALID=true

    IFS=',' read -ra BROWSERS <<< "$BROWSER_SELECTION"

    [ "${#BROWSERS[@]}" -eq 0 ] && VALID=false

    for browser in "${BROWSERS[@]}"; do
    case "$browser" in
        1) bash "$SCRIPT_DIR/brave.sh" ;;
        2) bash "$SCRIPT_DIR/chrome.sh" ;;
        3) bash "$SCRIPT_DIR/firefox.sh" ;;
    esac
done

    if [ "$VALID" = true ]; then
        break
    fi

    echo "Please select one or more browsers using comma-separated values (e.g. 1,3)."
    echo
done

echo
while :; do
    read -rp "Install Visual Studio Code? (y/N): " INSTALL_VSCODE
    [[ "$INSTALL_VSCODE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

echo
while :; do
    read -rp "Mount Fastgate SMB share? (y/N): " RUN_FASTGATE
    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

echo
while :; do
    read -rp "Apply system hardening at the end of installation? (y/N): " RUN_HARDENING
    [[ "$RUN_HARDENING" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

###############################################
# Variables
###############################################
TARGET_USER="${SUDO_USER:-${USER:-root}}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# Install dependencies for key management
###############################################
apt-get install -y gpg curl

###############################################
# Debian Repositories
###############################################
# Disable legacy sources.list
if [ -f /etc/apt/sources.list ]; then
  if [ ! -f /etc/apt/sources.list.bak ]; then
    mv /etc/apt/sources.list /etc/apt/sources.list.bak
  fi
fi

# Detect Debian codename
DEBIAN_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
DEBIAN_SOURCES="/etc/apt/sources.list.d/debian.sources"

write_if_changed "$DEBIAN_SOURCES" "$(cat << EOF
Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: $DEBIAN_CODENAME
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security/
Suites: $DEBIAN_CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://deb.debian.org/debian/
Suites: $DEBIAN_CODENAME-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
)"

###############################################
# Extra Repositories
###############################################
install -d -m 0755 /etc/apt/keyrings

# Browsers
BROWSERS_TO_INSTALL=()
for browser in "${BROWSERS[@]}"; do
        1)
            bash "$SCRIPT_DIR/brave.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/chrome.sh"
            ;;
        3)
            bash "$SCRIPT_DIR/firefox.sh"
            ;;
    esac
done

# Visual Studio Code
if [[ "$INSTALL_VSCODE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/vscode.sh"
fi

###############################################
# Update Repositories
###############################################
apt-get update

###############################################
# Initial Firmware, Drivers and Utilities
###############################################
apt-get install -y firmware-linux firmware-linux-nonfree firmware-misc-nonfree firmware-sof-signed firmware-realtek intel-media-va-driver-non-free firmware-iwlwifi

###############################################
# Desktop Environment
###############################################
case "$DESKTOP_CHOICE" in
    1)
        echo
        echo "Installing KDE Plasma..."
        bash "$SCRIPT_DIR/kde.sh" "$TARGET_USER"
        ;;
    2)
        echo
        echo "Installing GNOME..."
        bash "$SCRIPT_DIR/gnome.sh" "$TARGET_USER"
        ;;
esac

###############################################
# Apps & Utilities
###############################################
apt-get install -y timeshift vim htop fastfetch unrar plymouth-themes fwupd debsums starship nvme-cli rclone thermald unattended-upgrades

###############################################
# Browsers
###############################################
BROWSERS_TO_INSTALL=()

for browser in $BROWSER_SELECTION; do
    case "$browser" in
        1)
            BROWSERS_TO_INSTALL+=(brave-browser)
            ;;
        2)
            BROWSERS_TO_INSTALL+=(google-chrome-stable)
            ;;
        3)
            BROWSERS_TO_INSTALL+=(firefox)
            ;;
    esac
done

if [ ${#BROWSERS_TO_INSTALL[@]} -gt 0 ]; then
    apt-get install -y "${BROWSERS_TO_INSTALL[@]}"
fi

###############################################
# Visual Studio Code
###############################################
if [[ "$INSTALL_VSCODE" =~ ^[Yy]$ ]]; then
    apt-get install -y code
fi

###############################################
# Multimedia
###############################################
apt-get install -y ffmpeg gstreamer1.0-libav gstreamer1.0-vaapi gstreamer1.0-plugins-{bad,ugly}

###############################################
# Fonts & Icons
###############################################
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
apt-get install -y ttf-mscorefonts-installer fonts-ubuntu fonts-crosextra-carlito fonts-crosextra-caladea fonts-firacode
apt-get install -y papirus-icon-theme

###############################################
# Printing & Scanning
###############################################
apt-get install -y cups printer-driver-gutenprint printer-driver-cups-pdf
systemctl enable cups

###############################################
# Network Manager only
###############################################
INTERFACES_FILE="/etc/network/interfaces"

INTERFACES_CONTENT=$(cat << 'EOF'
auto lo
iface lo inet loopback
EOF
)

write_if_changed "$INTERFACES_FILE" "$INTERFACES_CONTENT"

###############################################
# GRUB
###############################################
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' /etc/default/grub
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"|' /etc/default/grub

###############################################
# Locale
###############################################
grep -q "^it_IT.UTF-8 UTF-8" /etc/locale.gen || \
  printf "it_IT.UTF-8 UTF-8\n" >> /etc/locale.gen

locale-gen

update-locale \
LANG=en_US.UTF-8 \
LANGUAGE=en_US:en \
LC_CTYPE="en_US.UTF-8" \
LC_NUMERIC=it_IT.UTF-8 \
LC_TIME=it_IT.UTF-8 \
LC_COLLATE="en_US.UTF-8" \
LC_MONETARY=it_IT.UTF-8 \
LC_MESSAGES="en_US.UTF-8" \
LC_PAPER=it_IT.UTF-8 \
LC_NAME=it_IT.UTF-8 \
LC_ADDRESS=it_IT.UTF-8 \
LC_TELEPHONE=it_IT.UTF-8 \
LC_MEASUREMENT=it_IT.UTF-8

###############################################
# Finalization
###############################################
usermod -aG libvirt,kvm,lpadmin "$TARGET_USER"
systemctl enable thermald
plymouth-set-default-theme lines -R
update-grub

###############################################
# Optional Fastgate setup
###############################################
if [ -f "$SCRIPT_DIR/fastgate.sh" ]; then
  if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/fastgate.sh"
  fi
fi

###############################################
# Optional Hardening setup
###############################################
if [ -f "$SCRIPT_DIR/hardening.sh" ]; then
  if [[ "$RUN_HARDENING" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/hardening.sh"
  fi
fi

###############################################
# Cleanup
###############################################
apt-get -y autoremove
apt-get clean

echo
echo "Installation completed."