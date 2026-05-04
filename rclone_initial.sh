#!/bin/bash

set -e

INSTALL_MARKER="$HOME/.config/rclone/.install_done"
BOOTSTRAP_MARKER="$HOME/.config/rclone/.bootstrap_done"

# =========================
# 1) SKIP IF ALREADY INSTALLED
# =========================
if [ -f "$INSTALL_MARKER" ]; then
  echo "⏭️ Already installed, skipping"
else
  echo "📦 Installing systemd service..."

  mkdir -p "$HOME/.config/systemd/user"

  cat > "$HOME/.config/systemd/user/rclone-sync.service" <<'EOF'
[Unit]
Description=Rclone live sync (local -> Google Drive)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple

ExecStartPre=/usr/bin/env bash -c '\
  : > /home/fabri/rclone.log; \
  rclone sync gdrive: /home/fabri/Documents \
    --drive-skip-gdocs \
    --exclude "*.tmp" \
    --exclude "*.swp" \
    --exclude "**/.git/**" \
    --exclude "**node_modules/**" \
    --log-file /home/fabri/rclone.log \
    --log-level INFO'

ExecStart=/home/fabri/Git/linux/rclone_watch.sh
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=default.target
EOF

  touch "$INSTALL_MARKER"
  echo "✅ Service installed"
fi

# =========================
# 2) BOOTSTRAP (REMOTE -> LOCAL, ONLY ONCE)
# =========================
if [ ! -f "$BOOTSTRAP_MARKER" ]; then
  echo "📦 Initial full Google Drive sync (remote -> local)..."

  if rclone sync gdrive: "$HOME/Documents" \
    --drive-skip-gdocs \
    --log-file "$HOME/rclone_bootstrap.log" \
    --log-level INFO; then

    touch "$BOOTSTRAP_MARKER"
    echo "✅ Bootstrap completed"
  else
    echo "❌ Bootstrap failed (marker NOT created)"
    exit 1
  fi
else
  echo "⏭️ Bootstrap already done"
fi

# =========================
# 3) START SERVICE
# =========================
systemctl --user daemon-reload
systemctl --user enable --now rclone-sync.service

loginctl enable-linger "$USER"

echo "🚀 Setup complete"
