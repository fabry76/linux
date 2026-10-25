#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
REPO_ID="nextcloud-office"
GPG_KEY="https://download.nextcloud.com/office/repo/nextcloud-office.asc"
EXPECTED_FINGERPRINT="C013F0BEF96800BBBC4D93DDE6E70E5FA287C3D0"
PKG="nextcloud-office-desktopeditors"

if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0" >&2
    exit 1
fi

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

curl -fsSL "$GPG_KEY" -o "$TMP_KEY"

ACTUAL_FINGERPRINT="$(
    gpg --show-keys --with-colons "$TMP_KEY" |
    awk -F: '$1 == "fpr" { print toupper($10); exit }'
)"

if [[ "$ACTUAL_FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]]; then
    echo "ERROR: GPG key fingerprint mismatch!" >&2
    echo "Expected: $EXPECTED_FINGERPRINT" >&2
    echo "Actual: ${ACTUAL_FINGERPRINT:-unavailable}" >&2
    exit 1
fi

rpm --import "$TMP_KEY"
echo "Repository signing key verified and imported."

printf '[%s]\nname=Nextcloud Office\nbaseurl=https://download.nextcloud.com/office/repo/rpm/stable/$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=%s\n' "$REPO_ID" "$GPG_KEY" > "$REPO_FILE"

echo "Repository configuration created."

dnf -y makecache --refresh

if ! rpm -q "$PKG" &>/dev/null; then
    dnf install -y "$PKG"
    echo "Package installed: $PKG"
else
    echo "Package already installed: $PKG"
fi

echo "Done."