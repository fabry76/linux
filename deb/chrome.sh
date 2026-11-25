#!/usr/bin/env bash
set -euo pipefail

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
# Repository
###############################################
CHROME_KEY="/etc/apt/keyrings/google-chrome.asc"

install -d -m 0755 /etc/apt/keyrings

TMP_CHROME_KEY="$(mktemp)"
trap 'rm -f "$TMP_CHROME_KEY"' EXIT

curl -fsSL \
    https://dl.google.com/linux/linux_signing_key.pub \
    -o "$TMP_CHROME_KEY"

if [ ! -f "$CHROME_KEY" ] || ! cmp -s "$TMP_CHROME_KEY" "$CHROME_KEY"; then
    install -m 0644 "$TMP_CHROME_KEY" "$CHROME_KEY"
fi

write_if_changed /etc/apt/sources.list.d/google-chrome.sources "$(cat << 'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.asc
EOF
)"

###############################################
# Installation
###############################################
# Prevent the package from adding its own repository and keyring
[ -e /etc/default/google-chrome ] || touch /etc/default/google-chrome

apt-get update
apt-get install -y google-chrome-stable