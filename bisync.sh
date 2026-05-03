BISYNC_INIT_MARKER="$HOME/.config/rclone/.bisync_initialized"

if [ ! -f "$BISYNC_INIT_MARKER" ]; then
  echo "📦 First bisync initialization..."
  if rclone bisync "$HOME/Documents" gdrive: --resync; then
    touch "$BISYNC_INIT_MARKER"
  else
    echo "❌ Bisync initialization failed"
    exit 1
  fi
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

write_if_changed "$HOME/.config/systemd/user/rclone-bisync.service" "$(cat <<'EOF'
[Unit]
Description=Rclone bisync Documents <-> GDrive
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot

ExecStart=/bin/sh -c '/usr/bin/flock -n /tmp/rclone-bisync.lock /usr/bin/rclone bisync /home/fabri/Documents gdrive: \
  --check-access \
  --check-first \
  --create-empty-src-dirs \
  --backup-dir /home/fabri/Downloads/Documents_backup_$(date +%F) \
  --log-file /home/fabri/rclone-bisync.log \
  --log-level INFO'

TimeoutStartSec=0
EOF
)"

write_if_changed "$HOME/.config/systemd/user/rclone-bisync.timer" "$(cat <<'EOF'
[Unit]
Description=Run rclone bisync every 15 minutes

[Timer]
OnBootSec=0
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
)"

systemctl --user daemon-reload
systemctl --user enable --now rclone-bisync.timer

loginctl enable-linger "$USER"