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
# Write if changed
###############################################
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
    printf "%s\n" "$content" > "$file"
  fi
}

###############################################
# Required paths
###############################################
DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")

mkdir -p \
  "$HOME/.config" \
  "$HOME/.config/mpv" \
  "$DESKTOP_DIR" \
  "$HOME/Virtual" \
  "$HOME/.local/share/konsole"
  
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
# KWRITE
###############################################
[ -f "$HOME/Git/linux/etc/kwriterc" ] && \
install -D \
  "$HOME/Git/linux/etc/kwriterc" \
  "$HOME/.config/kwriterc"

###############################################
# KKTORRENT
###############################################
[ -f "$HOME/Git/linux/etc/ktorrentrc" ] && \
install -D \
  "$HOME/Git/linux/etc/ktorrentrc" \
  "$HOME/.config/ktorrentrc"

###############################################
# Desktop icon
###############################################
[ -f "$HOME/Git/linux/etc/computer.desktop" ] && \
install -D \
  "$HOME/Git/linux/etc/computer.desktop" \
  "$HOME/Desktop/computer.desktop"

###############################################
# Konsole
###############################################
KONSOLERC="$HOME/.config/konsolerc"
KONSOLERC_CONTENT=$(cat <<EOF
[Desktop Entry]
DefaultProfile=FF.profile
Version=1.0

[General]
ConfigVersion=1
DefaultProfile=FF.profile

[UiSettings]
ColorScheme=
EOF
)

write_if_changed "$KONSOLERC" "$KONSOLERC_CONTENT"

[ -f "$HOME/Git/linux/etc/FF.profile" ] && \
install -D \
  "$HOME/Git/linux/etc/FF.profile" \
  "$HOME/.local/share/konsole/FF.profile"

###############################################
# Done
###############################################
echo "🚀 User customization completed."