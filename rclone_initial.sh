#!/bin/bash
set -euo pipefail

###############################################
# User validation
###############################################
if [ "$EUID" -eq 0 ]; then
  echo "Do not run as root"
  exit 1
fi

BOOTSTRAP_MARKER="$HOME/.config/rclone/.bootstrap_done"

# =========================
# 1) INSTALL / REFRESH systemd SERVICE
#    (always rewritten — daemon-reload + enable --now are idempotent,
#    so no marker is needed here)
# =========================
echo "📦 Installing/updating systemd service..."

mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/rclone-sync.service" <<'EOF'
[Unit]
Description=Rclone sync
Wants=network-online.target
After=network-online.target

[Service]
Type=simple

ExecStart=%h/Git/linux/rclone_watch.sh
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=default.target
EOF

echo "✅ Service file written"

# =========================
# 2) BOOTSTRAP (REMOTE -> LOCAL, ONLY ONCE)
# =========================
if [ ! -f "$BOOTSTRAP_MARKER" ]; then
  echo "📦 Initial full Google Drive sync (remote -> local)..."

  mkdir -p "$(dirname "$BOOTSTRAP_MARKER")"

  if rclone sync gdrive: "$HOME/Documents" \
    --drive-skip-gdocs \
    --progress \
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
