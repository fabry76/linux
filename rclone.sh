BISYNC_INIT_MARKER="$HOME/.config/rclone/.bisync_initialized"

if [ ! -f "$BISYNC_INIT_MARKER" ]; then
  echo "📦 First bisync initialization..."

  if rclone bisync "$HOME/Documents" gdrive: --resync \
       --drive-skip-gdocs; then
    touch "$BISYNC_INIT_MARKER"
    echo "✅ Bisync initialization completed"
  else
    echo "❌ Bisync initialization failed"
  fi

else
  echo "⏭️ Marker found: bisync initialization skipped (already done)"
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
Description=Rclone bisync Documents <-> Google Drive
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot

ExecStartPre=/usr/bin/truncate -s 0 /home/fabri/rclone.log

ExecStart=/usr/bin/flock -n /tmp/rclone-bisync.lock /usr/bin/rclone bisync /home/fabri/Documents gdrive: --check-first --drive-skip-gdocs --backup-dir gdrive:Documents_backup --log-file /home/fabri/rclone.log --log-level INFO

Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF
)"

write_if_changed "$HOME/.config/systemd/user/rclone-bisync.path" "$(cat <<'EOF'
[Unit]
Description=Watch Documents for changes (rclone bisync trigger)

[Path]
PathExistsGlob=/home/fabri/Documents/**/*

Unit=rclone-bisync.service

[Install]
WantedBy=default.target
EOF
)"

systemctl --user daemon-reload
systemctl --user enable --now rclone-bisync.path

loginctl enable-linger "$USER"