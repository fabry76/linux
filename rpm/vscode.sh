#!/usr/bin/env bash
set -euo pipefail

KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
REPO_URL="https://packages.microsoft.com/yumrepos/vscode/config.repo"
REPO_FILE="/etc/yum.repos.d/vscode.repo"
PKG="code"

# 1) Ensure Microsoft GPG key
echo "Ensuring Microsoft GPG key..."
curl -fsSL "$KEY_URL" | sudo rpm --import -

# 2) Ensure repository exists and is correct
if [[ ! -f "$REPO_FILE" ]] || ! grep -q "packages.microsoft.com/yumrepos/vscode" "$REPO_FILE"; then
  echo "Adding VS Code repository..."
  curl -fsSL "$REPO_URL" | sudo tee "$REPO_FILE" > /dev/null
else
  echo "VS Code repository already present"
fi

# 4) Install VS Code if missing
if ! rpm -q "$PKG" &>/dev/null; then
  echo "Installing VS Code..."
  sudo dnf install -y "$PKG"
else
  echo "VS Code already installed"
fi