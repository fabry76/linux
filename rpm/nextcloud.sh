#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
REPO_ID="nextcloud-office"
PKG="nextcloud-office-nextcloudoffice"
GPG_KEY="https://nextcloud.com"

# 1) Check root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0" >&2
    exit 1
fi

# 2) Configure Nextcloud Office repository
echo "Configuring Nextcloud Office repository..."

cat > "$REPO_FILE" <<'EOF'
[nextcloud-office]
name=Nextcloud Office
baseurl=https://nextcloud.com
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://nextcloud.com
EOF

echo "Repository configured."

# 3) Refresh DNF metadata
echo "Refreshing DNF metadata..."
dnf makecache --refresh

# 4) Install package if missing
if ! rpm -q "$PKG" &>/dev/null; then
    echo "Installing Nextcloud Office..."
    dnf install -y --nogpgcheck "$PKG"
else
    echo "Nextcloud Office already installed."
fi

echo "Done."