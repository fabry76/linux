#!/usr/bin/env bash
set -euo pipefail

###############################################
# Variables
###############################################
KEY_URL="https://download.nextcloud.com/office/repo/nextcloud-office.asc"
KEY_FILE="/etc/apt/keyrings/nextcloud-office.gpg"
SOURCES_FILE="/etc/apt/sources.list.d/nextcloud-office.sources"
PKG="nextcloud-office-desktopeditors"

###############################################
# Functions
###############################################
write_if_changed() {
  local file="$1"
  local content="$2"

  if [ -f "$file" ] && printf "%s" "$content" | cmp -s - "$file"; then
    return 0
  fi

  printf "%s" "$content" > "$file"
}

###############################################
# Checks
###############################################
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

###############################################
# Repository
###############################################
install -d -m 0755 /etc/apt/keyrings

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

curl -fsSL "$KEY_URL" | \
  gpg --batch --yes --dearmor --output "$TMP_KEY"

if [ ! -f "$KEY_FILE" ] || ! cmp -s "$TMP_KEY" "$KEY_FILE"; then
  install -m 0644 "$TMP_KEY" "$KEY_FILE"
fi

write_if_changed "$SOURCES_FILE" "$(cat << 'EOF'
Types: deb
URIs: https://download.nextcloud.com/office/repo/deb
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/nextcloud-office.gpg
EOF
)"

###############################################
# Installation
###############################################
apt-get update
apt-get install -y "$PKG"