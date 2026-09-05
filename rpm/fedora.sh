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
# Questions
###############################################
source "$GIT_DIR/questions.sh"
run_installer_questions

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
  rclone \
  unrar \
  tar \
  zip \
  wol \
  pciutils \
  bat \
  bind-utils \
  lsof \
  ncdu \
  nmap \
  rsync \
  smartmontools \
  traceroute \
  cabextract \
  inotify-tools \
  thermald
  
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

dnf install -y ffmpegthumbnailer intel-media-driver alsa-sof-firmware lsp-plugins-lv2 pipewire-module-filter-chain-lv2

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
dnf install -y cups gutenprint sane-backends
systemctl enable cups

AIRSCAN_CONF="/etc/sane.d/airscan.conf"

if ! grep -qE '^[[:space:]]*scanner[[:space:]]*=' "$AIRSCAN_CONF"; then
    sed -i \
        '/^\[devices\]$/a scanner = http://192.168.1.10/eSCL' \
        "$AIRSCAN_CONF"
fi

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

################################################
# Lid switch
################################################
LOGIND_LID_CONF="/etc/systemd/logind.conf.d/no-lid-suspend.conf"
LOGIND_LID_CONTENT="[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
"

if [ -f "$LOGIND_LID_CONF" ] &&
   printf "%s" "$LOGIND_LID_CONTENT" | cmp -s - "$LOGIND_LID_CONF"; then

    echo "Lid switch already configured, skipping."

else

    install -d -m 755 "$(dirname "$LOGIND_LID_CONF")"
    write_if_changed "$LOGIND_LID_CONF" "$LOGIND_LID_CONTENT"
    echo "Lid switch configured to ignore."

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
# Networking & Firewall
###############################################
dnf install -y \
    NetworkManager-wifi \
    iwlwifi-mvm-firmware \
    firewall-config

firewall-offline-cmd --set-default-zone=drop || true

systemctl enable firewalld

###############################################
# User session script
###############################################
USER_SCRIPT="$GIT_DIR/user_customization.sh"

if [ -f "$USER_SCRIPT" ]; then
    echo "Running user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE="$DESKTOP_CHOICE" bash "$USER_SCRIPT"
fi
