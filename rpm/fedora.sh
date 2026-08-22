#!/usr/bin/env bash
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
    echo
    echo "Please enter 1 for KDE or 2 for GNOME."
    echo
    read -rp "Selection: " DESKTOP_CHOICE

    [[ "$DESKTOP_CHOICE" =~ ^[12]$ ]] && break
done
echo

while :; do
    echo "Which main browser would you like to install?"
    echo "1) Brave"
    echo "2) Chrome"
    echo "3) Firefox"
    echo
    echo "Please select one or more browsers using comma-separated values (e.g. 1,3)."
    echo
    read -rp "Selection: " BROWSER_SELECTION
    
    VALID=true
    IFS=',' read -ra BROWSERS <<< "$BROWSER_SELECTION"

    for browser in "${BROWSERS[@]}"; do
        browser="${browser// /}"
        [[ $browser =~ ^[123]$ ]] || {
            VALID=false
            break
        }
    done

    $VALID && break
done
echo

while :; do
    echo "Which Flatpak browser would you like to install?"
    echo "0) None"
    echo "1) LibreWolf (io.gitlab.librewolf-community)"
    echo "2) Brave (com.brave.Browser)"
    echo "3) Firefox (org.mozilla.firefox)"
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
    echo

    read -rp "Choice [0-3]: " OFFICE_CHOICE

    [[ "$OFFICE_CHOICE" =~ ^[0-3]$ ]] && break

    echo "Please enter a number between 0 and 3."
done
echo

while :; do
    read -rp "Do you want to install Visual Studio Code? (Y/n): " INSTALL_VSCODE
    INSTALL_VSCODE="${INSTALL_VSCODE:-Y}"
    [[ "$INSTALL_VSCODE" =~ ^([Yy]|[Nn])$ ]] && break
    echo "Please answer y or n."
done
echo

while :; do
    read -rp "Do you want to mount the Fastgate SMB share? (Y/n): " RUN_FASTGATE
    RUN_FASTGATE="${RUN_FASTGATE:-Y}"

    [[ "$RUN_FASTGATE" =~ ^([Yy]|[Nn])$ ]] && break
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

        while :; do
            read -rp "Fastgate credentials already exist. Update credentials? (y/N): " CONFIRM
            CONFIRM="${CONFIRM:-N}"

            [[ "$CONFIRM" =~ ^([Yy]|[Nn])$ ]] && break
            echo "Please answer y or n."
        done

        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            CRED_STATE="update"
        fi
    fi

    if [ "$CRED_STATE" = "missing" ] ||
       [ "$CRED_STATE" = "invalid" ] ||
       [ "$CRED_STATE" = "update" ]; then

        echo
        
        read -rp "Username: " NAS_USER
        read -rsp "Password: " NAS_PASS
        echo

        OLD_UMASK="$(umask)"
        umask 077

        cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

        umask "$OLD_UMASK"

        chown root:root "$CRED_FILE"
        chmod 600 "$CRED_FILE"
    fi
fi
echo

while :; do
    read -rp "Do you want to apply system hardening at the end of installation? (Y/n): " RUN_HARDENING
    RUN_HARDENING="${RUN_HARDENING:-Y}"
    [[ "$RUN_HARDENING" =~ ^([Yy]|[Nn])$ ]] && break
    echo "Please answer y or n."
done

################################################
# Hostname
################################################
echo
read -rp "Enter the hostname for this system: " NEW_HOSTNAME
if [ -n "$NEW_HOSTNAME" ]; then
    CURRENT_HOSTNAME="$(hostnamectl --static)"
    if [ "$CURRENT_HOSTNAME" != "$NEW_HOSTNAME" ]; then
        hostnamectl set-hostname --static "$NEW_HOSTNAME"
        echo "Hostname changed from '$CURRENT_HOSTNAME' to '$NEW_HOSTNAME'."
    else
        echo "Hostname is already set to '$NEW_HOSTNAME'."
    fi
else
    echo "No hostname provided, keeping current hostname."
fi
echo

################################################
# Repositories, plugins and mirrors
################################################
dnf install -y \
dnf-plugins-core \
fedora-workstation-repositories \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Fast Mirror
if ! grep -q "^fastestmirror=True" /etc/dnf/dnf.conf; then
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
fi

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
  zip \
  xz \
  util-linux \
  coreutils \
  wol \
  upower \
  pciutils \
  bat \
  bind-utils \
  lsof \
  ncdu \
  nmap \
  rsync \
  smartmontools \
  traceroute \
  usbutils \
  cabextract
  
###############################################
# Starship
###############################################
STARSHIP_BIN="/usr/local/bin/starship"

if [[ -x "$STARSHIP_BIN" ]]; then
    echo "Starship already installed, skipping."
else
    STARSHIP_LATEST=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
        | grep -oP '"tag_name": "\K[^"]+')

    echo "Installing Starship ${STARSHIP_LATEST}..."

    STARSHIP_URL="https://github.com/starship/starship/releases/download/${STARSHIP_LATEST}/starship-x86_64-unknown-linux-gnu.tar.gz"

    TMP_FILE=$(mktemp)
    trap 'rm -f "$TMP_FILE"' EXIT

    curl -fsSL "$STARSHIP_URL" -o "$TMP_FILE"
    tar -xzf "$TMP_FILE" -C /usr/local/bin/

    chmod 755 "$STARSHIP_BIN"

    echo "Starship ${STARSHIP_LATEST} installed."
fi

###############################################
# Multimedia
###############################################
dnf swap -y ffmpeg-free ffmpeg --allowerasing

dnf install -y @multimedia \
  --setopt=install_weak_deps=False \
  --exclude=PackageKit-gstreamer-plugin

dnf install -y ffmpegthumbnailer intel-media-driver alsa-sof-firmware 

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
# Fonts & Icons
###############################################
dnf install -y \
  google-noto-sans-fonts \
  google-noto-serif-fonts \
  google-noto-color-emoji-fonts \
  fira-code-fonts \
  liberation-fonts \
  papirus-icon-theme

# Ubuntu fonts
FONT_SRC="$TARGET_HOME/Fastgate/Varie/fonts/ubuntu"
FONT_DST="/usr/local/share/fonts/ubuntu"

install -d -m 755 "$FONT_DST"

shopt -s nocaseglob

if compgen -G "$FONT_SRC/*.ttf" > /dev/null; then
    FONT_CHANGED=false

    for font in "$FONT_SRC"/*.ttf; do
        dest="$FONT_DST/$(basename "$font")"

        if [[ ! -f "$dest" ]] || ! cmp -s "$font" "$dest"; then
            install -m 644 "$font" "$dest"
            FONT_CHANGED=true
        fi
    done

    shopt -u nocaseglob

    if [[ "$FONT_CHANGED" == true ]]; then
        echo "Updating Ubuntu font cache..."
        fc-cache -f "$FONT_DST"
    else
        echo "Ubuntu fonts already up to date."
    fi
else
    shopt -u nocaseglob
    echo "WARNING: No Ubuntu TTF fonts found in $FONT_SRC"
fi

# MS Core Fonts
FONT_SRC="$TARGET_HOME/Fastgate/Varie/fonts/ms-fonts"
FONT_DST="/usr/local/share/fonts/ms-fonts"

install -d -m 755 "$FONT_DST"

shopt -s nocaseglob

if compgen -G "$FONT_SRC/*.ttf" > /dev/null; then
    FONT_CHANGED=false

    for font in "$FONT_SRC"/*.ttf; do
        dest="$FONT_DST/$(basename "$font")"

        if [[ ! -f "$dest" ]] || ! cmp -s "$font" "$dest"; then
            install -m 644 "$font" "$dest"
            FONT_CHANGED=true
        fi
    done
    
    shopt -u nocaseglob

    if [[ "$FONT_CHANGED" == true ]]; then
        echo "Updating MS font cache..."
        fc-cache -f "$FONT_DST"
    else
        echo "MS fonts already up to date."
    fi
else
    shopt -u nocaseglob
    echo "WARNING: No MS TTF fonts found in $FONT_SRC"
fi

###############################################
# Printing & Scanning
###############################################
dnf install -y cups gutenprint cups-pdf
systemctl enable cups

###############################################
# Locale
###############################################
# Install Italian locale data
dnf install -y glibc-langpack-it

# English UI, Italian regional formats
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
# Hardening
###############################################
if [ -f "$SCRIPT_DIR/hard_fed.sh" ]; then
  if [[ "$RUN_HARDENING" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/hard_fed.sh"
  fi
fi

###############################################
# Networking & Firewall
###############################################
dnf install -y \
    NetworkManager-wifi \
    iwlwifi-mvm-firmware \
    firewalld \
    firewall-config

firewall-offline-cmd --set-default-zone=drop || true

systemctl enable firewalld

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
