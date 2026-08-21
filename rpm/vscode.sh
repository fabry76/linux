#!/usr/bin/env bash
set -euo pipefail

KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
REPO_FILE="/etc/yum.repos.d/vscode.repo"
PKG="code"

# 1) Microsoft GPG key
echo "Ensuring Microsoft GPG key..."
curl -fsSL "$KEY_URL" | rpm --import -

# 2) Configure VS Code repository
echo "Configuring VS Code repository..."
cat > "$REPO_FILE" <<'EOF'
[vscode-yum]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# 3) Refresh metadata
echo "Refreshing DNF metadata..."
dnf makecache --refresh

# 4) Install VS Code if missing
if ! rpm -q "$PKG" &>/dev/null; then
    echo "Installing VS Code..."
    dnf install -y "$PKG"
else
    echo "VS Code already installed"
fi