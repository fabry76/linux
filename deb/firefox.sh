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
MOZILLA_KEY="/etc/apt/keyrings/packages.mozilla.org.asc"

install -d -m 0755 /etc/apt/keyrings

TMP_MOZILLA_KEY="$(mktemp)"
trap 'rm -f "$TMP_MOZILLA_KEY"' EXIT

curl -fsSL \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    -o "$TMP_MOZILLA_KEY"

if [ ! -f "$MOZILLA_KEY" ] || ! cmp -s "$TMP_MOZILLA_KEY" "$MOZILLA_KEY"; then
    install -m 0644 "$TMP_MOZILLA_KEY" "$MOZILLA_KEY"
fi

write_if_changed /etc/apt/sources.list.d/mozilla.sources "$(cat <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
)"

# Prefer the Mozilla package over the Ubuntu snap stub (Ubuntu only)
if [ "$DISTRO" = "ubuntu" ]; then
    write_if_changed /etc/apt/preferences.d/mozilla "$(cat <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
)"
fi

###############################################
# Installation
###############################################
apt-get update
apt-get install -y firefox
