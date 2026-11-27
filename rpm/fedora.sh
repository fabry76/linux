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

DISTRO="fedora"
export DISTRO

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

# install_fonts <label> <source dir> <destination dir>
install_fonts() {
  local label="$1"
  local src="$2"
  local dst="$3"
  local changed=false
  local fonts font dest

  install -d -m 755 "$dst"

  shopt -s nocaseglob
  fonts=("$src"/*.ttf)
  shopt -u nocaseglob

  if [[ ! -e "${fonts[0]}" ]]; then
    echo "WARNING: No $label TTF fonts found in $src"
    return 0
  fi

  for font in "${fonts[@]}"; do
    dest="$dst/$(basename "$font")"

    if [[ ! -f "$dest" ]] || ! cmp -s "$font" "$dest"; then
      install -m 644 "$font" "$dest"
      changed=true
    fi
  done

  if [[ "$changed" == true ]]; then
    echo "Updating $label font cache..."
    fc-cache -f "$dst"
  else
    echo "$label fonts already up to date."
  fi
}

# Downloads the latest Starship release and verifies its SHA-256
# checksum (published next to the tarball) before installing it.
install_starship() {
  local bin="/usr/local/bin/starship"
  local base="https://github.com/starship/starship/releases/latest/download"
  local asset="starship-x86_64-unknown-linux-gnu.tar.gz"
  local curl_opts=(-fsSL --retry 5 --retry-delay 2 --retry-max-time 60
                   --connect-timeout 15 --max-time 90)
  local tmp expected actual

  if [[ -x "$bin" ]]; then
    echo "Starship already installed, skipping."
    return 0
  fi

  tmp=$(mktemp -d)

  if ! curl "${curl_opts[@]}" "$base/$asset" -o "$tmp/$asset" ||
     ! curl "${curl_opts[@]}" "$base/$asset.sha256" -o "$tmp/$asset.sha256"; then
    echo "WARNING: Could not download Starship; continuing without it."
    rm -rf "$tmp"
    return 0
  fi

  expected=$(awk '{print $1; exit}' "$tmp/$asset.sha256")
  actual=$(sha256sum "$tmp/$asset" | awk '{print $1}')

  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    echo "WARNING: Starship checksum mismatch; skipping installation."
    rm -rf "$tmp"
    return 0
  fi

  if tar -xzf "$tmp/$asset" -C "$tmp" starship &&
     install -m 755 "$tmp/starship" "$bin"; then
    echo "Starship installed (checksum verified)."
  else
    echo "WARNING: Could not install Starship; continuing without it."
  fi

  rm -rf "$tmp"
}

###############################################
# Full Verbose Logging
###############################################
LOG_FILE="$TARGET_HOME/install.log"
runuser -u "$TARGET_USER" -- touch "$LOG_FILE"
exec > >(runuser -u "$TARGET_USER" -- tee -a "$LOG_FILE") 2>&1

###############################################
# DNF configuration & system update
###############################################
if ! grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
fi

dnf upgrade -y --refresh

###############################################
# Questions
###############################################
source "$GIT_DIR/questions.sh"
run_installer_questions

export DESKTOP_CHOICE

################################################
# Repositories, plugins and mirrors
################################################
dnf install -y \
dnf-plugins-core \
fedora-workstation-repositories \
https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

###############################################
# Desktop Environment
###############################################
case "$DESKTOP_CHOICE" in
    1)
        echo
        echo "Installing KDE Plasma..."
        bash "$SCRIPT_DIR/kde.sh" "$TARGET_USER" "$INSTALL_FLATPAK"
        ;;
    2)
        echo
        echo "Installing GNOME..."
        bash "$SCRIPT_DIR/gnome.sh" "$TARGET_USER" "$INSTALL_FLATPAK"
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
# Office
###############################################
if [[ "$INSTALL_OFFICE" =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/nextcloud.sh"
fi

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
  unzip \
  wol \
  pciutils \
  bat \
  bind-utils \
  lsof \
  ncdu \
  nmap \
  rsync \
  smartmontools \
  nvme-cli \
  traceroute \
  cabextract \
  inotify-tools

# Thermal daemon (only on Intel CPUs)
if grep -qs GenuineIntel /proc/cpuinfo; then
    dnf install -y thermald
fi

###############################################
# Starship
###############################################
install_starship

###############################################
# Multimedia
###############################################
dnf swap -y ffmpeg-free ffmpeg --allowerasing

dnf install -y @multimedia \
  --setopt=install_weak_deps=False \
  --exclude=PackageKit-gstreamer-plugin

dnf install -y ffmpegthumbnailer alsa-sof-firmware lsp-plugins-lv2 pipewire-module-filter-chain-lv2

# Intel media driver (only with an Intel GPU)
if grep -qs 0x8086 /sys/class/drm/card*/device/vendor; then
    dnf install -y intel-media-driver
fi

###############################################
# Fastgate
###############################################
if [[ "$RUN_FASTGATE" =~ ^[Yy]$ ]]; then
    dnf install -y cifs-utils
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
  google-noto-sans-cjk-fonts \
  google-noto-serif-cjk-fonts \
  google-carlito-fonts \
  google-crosextra-caladea-fonts \
  fira-code-fonts \
  liberation-fonts \
  papirus-icon-theme

install_fonts "Ubuntu"   "$TARGET_HOME/Fastgate/Varie/fonts/ubuntu"   "/usr/local/share/fonts/ubuntu"
install_fonts "MS Core"  "$TARGET_HOME/Fastgate/Varie/fonts/ms-fonts" "/usr/local/share/fonts/ms-fonts"

###############################################
# Printing & Scanning
###############################################
dnf install -y cups gutenprint sane-backends
systemctl enable cups

if [ -n "$(systemctl list-unit-files --no-legend cups-browsed.service)" ]; then
    systemctl disable cups-browsed.service
fi

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

install -d -m 755 "$(dirname "$LOGIND_LID_CONF")"
write_if_changed "$LOGIND_LID_CONF" "$LOGIND_LID_CONTENT"
chmod 644 "$LOGIND_LID_CONF"

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
    firewall-config

# Intel Wi-Fi firmware (only with an Intel wireless card:
# PCI vendor 0x8086, class 0x0280 = network controller)
INTEL_WIFI=false
for dev in /sys/bus/pci/devices/*; do
    [ -r "$dev/vendor" ] && [ -r "$dev/class" ] || continue

    if [[ "$(<"$dev/vendor")" == "0x8086" && "$(<"$dev/class")" == 0x0280* ]]; then
        INTEL_WIFI=true
        break
    fi
done

if [ "$INTEL_WIFI" = true ]; then
    dnf install -y iwlwifi-mvm-firmware
fi

firewall-offline-cmd --set-default-zone=drop || true

systemctl enable firewalld

###############################################
# User session script
###############################################
USER_SCRIPT="$GIT_DIR/user_customization.sh"

if [ -f "$USER_SCRIPT" ]; then
    echo "Running user session script: $USER_SCRIPT"

    runuser -u "$TARGET_USER" -- env DESKTOP_CHOICE="$DESKTOP_CHOICE" DISTRO="$DISTRO" bash "$USER_SCRIPT"
fi