#!/usr/bin/env bash
set -euo pipefail

PKG="google-chrome-stable"

# Enable the google-chrome repo (dnf5 syntax)
dnf config-manager setopt google-chrome.enabled=1

# Idempotent install
if ! rpm -q "$PKG" &>/dev/null; then
  dnf install -y "$PKG"
else
  echo "Package already installed: $PKG"
fi
