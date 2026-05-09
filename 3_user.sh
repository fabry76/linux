#!/bin/bash
set -euo pipefail

###############################################
# User validation
###############################################
if [ "$EUID" -eq 0 ]; then
  echo "Do not run as root"
  exit 1
fi

###############################################
# Required paths
###############################################
mkdir -p \
  "$HOME/.config" \
  "$HOME/.config/mpv" \
  "$HOME/Desktop" \
  "$HOME/Virtual"

###############################################
# Flatpak overrides
###############################################
flatpak override --user org.onlyoffice.desktopeditors \
  --env=GTK_USE_PORTAL=1 \
  --env=GTK_THEME=Breeze:dark

###############################################
# Starship
###############################################
grep -qF 'eval "$(starship init bash)"' "$HOME/.bashrc" || \
  echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"

[ -f "$HOME/Git/linux/etc/starship.toml" ] && \
install -D \
  "$HOME/Git/linux/etc/starship.toml" \
  "$HOME/.config/starship.toml"

###############################################
# MPV
###############################################
[ -f "$HOME/Git/linux/etc/mpv.conf" ] && \
install -D \
  "$HOME/Git/linux/etc/mpv.conf" \
  "$HOME/.config/mpv/mpv.conf"

###############################################
# Desktop icon
###############################################
[ -f "$HOME/Git/linux/etc/computer.desktop" ] && \
install -D \
  "$HOME/Git/linux/etc/computer.desktop" \
  "$HOME/Desktop/computer.desktop"

###############################################
# Done
###############################################
echo "User customization completed."