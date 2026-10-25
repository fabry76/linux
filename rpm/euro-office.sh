#!/usr/bin/env bash
set -euo pipefail

# Repository configuration
REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
REPO_ID="nextcloud-office"
GPG_KEY="https://download.nextcloud.com/office/repo/nextcloud-office.asc"

# Package name
PKG="nextcloud-office-desktopeditors"

# 1) Check for root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0" >&2
    exit 1
fi

# 2) Idempotent repository setup
if [[ ! -f "$REPO_FILE" ]] ||
   ! grep -q "^\[$REPO_ID\]$" "$REPO_FILE"; then

    cat > "$REPO_FILE" <<'EOF'
[nextcloud-office]
name=Nextcloud Office
baseurl=https://download.nextcloud.com/office/repo/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://download.nextcloud.com/office/repo/nextcloud-office.asc
EOF

    echo "Repository configuration created."
else
    echo "Repository already configured."
fi

# 3) Import the repository signing key
rpm --import "$GPG_KEY"

# 4) Refresh repository metadata
dnf makecache --refresh

# 5) Idempotent package installation
if ! rpm -q "$PKG" &>/dev/null; then
    dnf install -y "$PKG"
    echo "Package installed: $PKG"
else
    echo "Package already installed: $PKG"
fi
