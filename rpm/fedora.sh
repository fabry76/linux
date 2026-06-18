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
    echo "Which desktop environment would you like to install?"
    echo "1) KDE"
    echo "2) GNOME"
    read -rp "Choice [1-2]: " DESKTOP_CHOICE

    [[ "$DESKTOP_CHOICE" =~ ^[12]$ ]] && break

    echo "Please enter 1 for KDE or 2 for GNOME."
done
echo

while :; do
    echo "Which main browser would you like to install?"
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
        browser="${browser// /}"

        case "$browser" in
            1|2|3)
                ;;
            *)
                VALID=false
                break
                ;;
        esac
    done

    [ "$VALID" = true ] && break

    echo "Please select one or more browsers using comma-separated values (e.g. 1,3)."
done
echo

while :; do
    echo "Which Flatpak browser would you like to install?"
    echo "0) None"
    echo "1) Firefox (org.mozilla.firefox)"
    echo "2) Brave (com.brave.Browser)"
    echo "3) LibreWolf (io.gitlab.librewolf-community)"
    echo

    read -rp "Choice [0-3]: " FLATPAK_BROWSER

    [[ "$FLATPAK_BROWSER" =~ ^[0-3]$ ]] && break

    echo "Please enter a number between 0 and 3."
done
echo

while :; do
    echo "Which Office suite would you like to install?"
    echo "0) None"
    echo "1) ONLYOFFICE (org.onlyoffice.desktopeditors)"
    echo "2) LibreOffice (org.libreoffice.LibreOffice)"
    echo "3) Collabora Office (com.collaboraoffice.Office)"
    
    read -rp "Choice [0-3]: " OFFICE_CHOICE

    [[ "$OFFICE_CHOICE" =~ ^[0-3]$ ]] && break

    echo "Please enter a number between 0 and 3."
done
echo

while :; do
    read -rp "Do you want to install Visual Studio Code? (y/N): " INSTALL_VSCODE
    [[ "$INSTALL_VSCODE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done
echo

while :; do
    read -rp "Do you want to install VM support? (y/N): " INSTALL_VM
    [[ "$INSTALL_VM" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done
echo

while :; do
    read -rp "Do you want to mount the Fastgate SMB share? (y/N): " RUN_FASTGATE
    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done
echo

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
echo

while :; do
    read -rp "Do you want to apply system hardening at the end of installation? (y/N): " RUN_HARDENING
    [[ "$RUN_HARDENING" =~ ^([Yy]|[Nn]|)$ ]] && break
    echo "Please answer y or n."
done

################################################
# Repositories, plugins and mirrors
################################################
dnf install -y \
dnf-plugins-core \
fedora-workstation-repositories \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

grep -q "^fastestmirror=True" /etc/dnf/dnf.conf \
|| echo "fastestmirror=True" >> /etc/dnf/dnf.conf

###############################################
# Desktop Environment
###############################################
case "$DESKTOP_CHOICE" in
    1)
        echo
        echo "Installing KDE Plasma..."
        bash "$SCRIPT_DIR/kde.sh" "$TARGET_USER" "$FLATPAK_BROWSER" "$OFFICE_CHOICE"
        ;;
    2)
        echo
        echo "Installing GNOME..."
        bash "$SCRIPT_DIR/gnome.sh" "$TARGET_USER" "$FLATPAK_BROWSER" "$OFFICE_CHOICE"
        ;;
esac

###############################################
# Browsers
###############################################
BROWSERS_TO_INSTALL=()
for browser in "${BROWSERS[@]}"; do
    browser="${browser// /}"

    case "$browser" in
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

###############################################
# Visual Studio Code
###############################################
if [[ "$INSTALL_VSCODE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/vscode.sh"
fi

###############################################
# Applications & Utilities
###############################################
dnf install -y \
  vim \
  htop \
  fastfetch \
  curl \
  rclone \
  unrar \
  tar \
  gzip \
  xz \
  util-linux \
  coreutils \
  dnf-automatic
  
# Starship
curl -fsSL https://starship.rs/install.sh | sh -s -- -y >/dev/null 2>&1

###############################################
# Multimedia
###############################################
dnf swap -y ffmpeg-free ffmpeg --allowerasing

dnf install -y @multimedia \
  --setopt=install_weak_deps=False \
  --exclude=PackageKit-gstreamer-plugin

dnf install -y ffmpegthumbnailer intel-media-driver

###############################################
# Fonts & Icons
###############################################
dnf install -y \
  google-noto-sans-fonts \
  google-noto-serif-fonts \
  google-noto-color-emoji-fonts \
  fira-code-fonts \
  liberation-fonts \
  fira-code-fonts \
  papirus-icon-theme
  
###############################################
# Printing & Scanning
###############################################
dnf install -y cups gutenprint cups-pdf
systemctl enable cups

###############################################
# VM Support
###############################################
if [[ "$INSTALL_VM" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/virtualization.sh" "$TARGET_USER" "$DESKTOP_CHOICE"
fi

###############################################
# Locale
###############################################
localectl set-locale \
LANG=en_US.UTF-8 \
LC_NUMERIC=it_IT.UTF-8 \
LC_TIME=it_IT.UTF-8 \
LC_MONETARY=it_IT.UTF-8 \
LC_PAPER=it_IT.UTF-8 \
LC_NAME=it_IT.UTF-8 \
LC_ADDRESS=it_IT.UTF-8 \
LC_TELEPHONE=it_IT.UTF-8 \
LC_MEASUREMENT=it_IT.UTF-8

###############################################
# Fastgate
###############################################
if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    dnf install -y cifs-utils
    systemctl enable NetworkManager
    systemctl restart NetworkManager
    bash "$GIT_DIR/fastgate.sh"
fi

###############################################
# Hardening
###############################################
if [ -f "$SCRIPT_DIR/hard_fed.sh" ]; then
  if [[ "$RUN_HARDENING" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/hard_fed.sh"
  fi
fi

###############################################
# Firewall
###############################################
dnf install -y firewalld firewall-config
systemctl enable firewalld
firewall-cmd --permanent --add-service=mdns
firewall-cmd --permanent --remove-service={ssh,dhcpv6-client}
firewall-cmd --reload

###############################################
# Cleanup
###############################################
dnf update -y
dnf clean all
sudo dnf makecache --refresh -q
echo "System installation completed."

###############################################
# User session script
###############################################
USER_SCRIPT=""

case "$DESKTOP_CHOICE" in
    1)
        USER_SCRIPT="kde_user.sh"
        ;;
    2)
        USER_SCRIPT="gnome_user.sh"
        ;;
    *)
        USER_SCRIPT=""
        ;;
esac

if [ -n "$USER_SCRIPT" ] && [ -f "$GIT_DIR/$USER_SCRIPT" ]; then
    echo "Switching to user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- bash "$GIT_DIR/$USER_SCRIPT"
fi