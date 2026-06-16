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

  if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
    return 0
  fi

  printf "%s" "$content" > "$file"
}

###############################################
# Required paths
###############################################
xdg-user-dirs-update

DESKTOP_DIR="$(xdg-user-dir DESKTOP)"

mkdir -p \
  "$HOME/.config" \
  "$HOME/.config/mpv" \
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
# Desktop icon
###############################################
[ -f "$HOME/Git/linux/etc/computer.desktop" ] && \
install -D \
  "$HOME/Git/linux/etc/computer.desktop" \
  "$DESKTOP_DIR/computer.desktop"

###############################################
# Konsole
###############################################
KONSOLERC="$HOME/.config/konsolerc"
KONSOLERC_CONTENT=$(cat <<EOF
[Desktop Entry]
DefaultProfile=ff.profile
Version=1.0

[General]
ConfigVersion=1
DefaultProfile=ff.profile

[UiSettings]
ColorScheme=
EOF
)

write_if_changed "$KONSOLERC" "$KONSOLERC_CONTENT"

[ -f "$HOME/Git/linux/etc/ff.profile" ] && \
install -D \
  "$HOME/Git/linux/etc/ff.profile" \
  "$HOME/.local/share/konsole/ff.profile"

###############################################
# Locale
###############################################
[ -f "$HOME/Git/linux/etc/plasma-localerc" ] && \
install -D \
  "$HOME/Git/linux/etc/plasma-localerc" \
  "$HOME/.config/plasma-localerc"

###############################################
# Git setup
###############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/git.sh" ]; then
  echo "Running Git setup..."
  bash "$SCRIPT_DIR/git.sh"
fi

###############################################
# Done
###############################################
echo "User customization completed."
