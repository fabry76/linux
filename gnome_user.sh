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
    "$HOME/Virtual"

###############################################
# Shortcuts
###############################################
SRC_BRV="/usr/share/applications/brave-origin.desktop"
DST_BRV="$HOME/.local/share/applications/brave-origin.desktop"

if [[ -f "$SRC_BRV" && ! -f "$DST_BRV" ]]; then
    mkdir -p "$(dirname "$DST_BRV")"
    cp "$SRC_BRV" "$DST_BRV"
    sed -i 's/^StartupNotify=true$/StartupNotify=false/' "$DST_BRV"
elif [[ ! -f "$SRC_BRV" ]]; then
    echo "Brave not installed, skipping shortcut"
else
    echo "Brave shortcut already exists, skipping"
fi

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
