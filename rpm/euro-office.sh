#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
REPO_ID="nextcloud-office"
GPG_KEY="https://download.nextcloud.com/office/repo/nextcloud-office.asc"
EXPECTED_FINGERPRINT="C013F0BEF96800BBBC4D93DDE6E70E5FA287C3D0"
PKG="nextcloud-office-desktopeditors"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with: sudo $0" >&2
    exit 1
fi

for cmd in curl gpg rpm dnf; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing command: $cmd" >&2
        exit 1
    }
done

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

curl -fsSL "$GPG_KEY" -o "$TMP_KEY"

ACTUAL_FINGERPRINT="$(
    gpg --batch --show-keys --with-colons "$TMP_KEY" |
    awk -F: '$1 == "fpr" { print toupper($10); exit }'
)"

if [[ "$ACTUAL_FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]]; then
    echo "ERROR: GPG fingerprint mismatch." >&2
    exit 1
fi

rpm --import "$TMP_KEY"

printf '[%s]\nname=Nextcloud Office\nbaseurl=https://download.nextcloud.com/office/repo/rpm/stable/$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=%s\n' \
    "$REPO_ID" "$GPG_KEY" > "$REPO_FILE"

dnf clean metadata

if ! dnf -y --refresh makecache --repo="$REPO_ID"; then
    echo "ERROR: Repository GPG verification failed." >&2
    exit 1
fi

if rpm -q "$PKG" >/dev/null 2>&1; then
    echo "Package already installed: $PKG"
else
    dnf install -y "$PKG"
    echo "Package installed: $PKG"
fi

echo "Done."