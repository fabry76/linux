#!/usr/bin/env bash
set -euo pipefail

DISTRO="${DISTRO:?DISTRO is not defined (the calling script must export it)}"

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
# Ubuntu Firefox Snap
###############################################
if [ "$DISTRO" = "ubuntu" ] && \
   command -v snap >/dev/null 2>&1 && \
   snap list firefox >/dev/null 2>&1; then

    echo "Firefox Snap is already installed."
    echo "Keeping the Ubuntu Firefox Snap."
    exit 0
fi

###############################################
# Mozilla repository
###############################################
install -d -m 0755 /etc/apt/keyrings

TMP_MOZILLA_KEY="$(mktemp)"

curl -fsSL \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -o "$TMP_MOZILLA_KEY"

if [ ! -f /etc/apt/keyrings/mozilla.gpg ] || \
   ! cmp -s "$TMP_MOZILLA_KEY" /etc/apt/keyrings/mozilla.gpg; then
    install -m 0644 "$TMP_MOZILLA_KEY" /etc/apt/keyrings/mozilla.gpg
fi

rm -f "$TMP_MOZILLA_KEY"

write_if_changed /etc/apt/sources.list.d/mozilla.sources "$(cat <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/mozilla.gpg
EOF
)"

###############################################
# Installation
###############################################
apt-get update
apt-get install -y firefox
