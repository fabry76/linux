###############################################
# RCLONE AUTO SYNC
###############################################
# Check directory state and bootstrap if empty
if [ -d "$HOME/Documents" ] && [ -n "$(ls -A "$HOME/Documents" 2>/dev/null)" ]; then
  echo "❌ ERROR: $HOME/Documents is not empty. Aborting setup to prevent data overwrite."
  exit 1
fi

if [ ! -d "$HOME/Documents" ] || [ -z "$(ls -A "$HOME/Documents" 2>/dev/null)" ]; then
  echo "📦 Directory is empty: running bootstrap from GDrive..."
  rclone copy gdrive: "$HOME/Documents"
fi

# write_if_changed function
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
    printf "%s\n" "$content" > "$file"
  fi
}

# Create systemd user service directory
mkdir -p "$HOME/.config/systemd/user"

write_if_changed "$HOME/.config/systemd/user/rclone-sync.service" "$(cat <<'EOF'
[Unit]
Description=Rclone sync GDrive -> Documents (dated backup)
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot

ExecStart=/bin/sh -c '/usr/bin/rclone sync gdrive: /home/fabri/Documents --backup-dir /home/fabri/Downloads/Documents_backup_$(date +%%F) -v > /home/fabri/rclone-sync.log 2>&1'

RemainAfterExit=yes
TimeoutStartSec=0
Restart=no

[Install]
WantedBy=default.target
EOF
)"

systemctl --user daemon-reload
systemctl --user enable rclone-sync.service
loginctl enable-linger "$USER"