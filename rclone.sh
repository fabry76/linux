###############################################
# RCLONE AUTO SYNC
###############################################

TARGET_USER="$(id -un)"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

write_if_changed() {
  local file="$1"
  local content="$2"

  if [ ! -f "$file" ] || [ "$(cat "$file")" != "$content" ]; then
    printf "%s\n" "$content" > "$file"
  fi
}

mkdir -p "$TARGET_HOME/.config/systemd/user"

###############################################
# SYNC IN (login)
###############################################
write_if_changed "$TARGET_HOME/.config/systemd/user/rclone-sync-in.service" "$(cat <<EOF
[Unit]
Description=Rclone sync GDrive -> Documents (login)
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/rclone sync gdrive: \$HOME/Documents --create-empty-src-dirs -v > \$HOME/rclone-in.log 2>&1'

[Install]
WantedBy=graphical-session.target
EOF
)"

###############################################
# SYNC OUT (logout/shutdown best effort)
###############################################
write_if_changed "$TARGET_HOME/.config/systemd/user/rclone-sync-out.service" "$(cat <<EOF
[Unit]
Description=Rclone sync Documents -> GDrive (shutdown best effort)
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/rclone sync "$HOME/Documents" gdrive: -P >> "$HOME/rclone-out.log" 2>&1'
TimeoutStartSec=0
TimeoutStopSec=10min

[Install]
WantedBy=default.target
EOF
)"

###############################################
# ENABLE SERVICES
###############################################
systemctl --user daemon-reload
systemctl --user enable rclone-sync-in.service
systemctl --user enable rclone-sync-out.service

loginctl enable-linger "$TARGET_USER"
