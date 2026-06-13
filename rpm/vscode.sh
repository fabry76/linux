#!/usr/bin/env bash
set -euo pipefail

# Microsoft VS Code repo + package
KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
REPO_URL="https://packages.microsoft.com/yumrepos/vscode/config.repo"
PKG="code"

# 1) Import GPG key (RPM is inherently idempotent)
curl -fsSL "$KEY_URL" | sudo rpm --import -
echo "GPG key ensured"

# 2) Install repository (DNF handles idempotence)
sudo dnf install -y "$REPO_URL"
echo "VS Code repository ensured"

# 3) Install package (RPM check)
if ! rpm -q "$PKG" &>/dev/null; then
  sudo dnf install -y "$PKG"
  echo "VS Code installed"
else
  echo "VS Code already installed"
fi

