#!/usr/bin/env bash
set -euo pipefail

PKG="firefox"

if ! rpm -q "$PKG" &>/dev/null; then
  dnf install -y "$PKG"
else
  echo "Package already installed: $PKG"
fi
