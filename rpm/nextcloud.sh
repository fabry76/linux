#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
PKG="nextcloud-office-desktopeditors"
GPG_KEY="https://download.nextcloud.com/office/repo/nextcloud-office.asc"

# 1) Check root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0" >&2
    exit 1
fi

# 2) Import the signing key
echo "Importing GPG key..."
rpm --import "$GPG_KEY"

# 3) Configure the Nextcloud Office repository
#    Quoted heredoc: $basearch must reach DNF unexpanded.
echo "Configuring Nextcloud Office repository..."
cat > "$REPO_FILE" <<'EOF'
[nextcloud-office]
name=Nextcloud Office
baseurl=https://download.nextcloud.com/office/repo/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=https://download.nextcloud.com/office/repo/nextcloud-office.asc
EOF

# 4) Refresh DNF metadata
echo "Refreshing DNF metadata..."
dnf makecache --refresh

# 5) Install package if missing
if ! rpm -q "$PKG" &>/dev/null; then
    echo "Installing Nextcloud Office Desktop Editors..."
    dnf install -y "$PKG"
else
    echo "Nextcloud Office Desktop Editors already installed."
fi

echo "Done."