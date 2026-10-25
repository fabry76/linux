#!/usr/bin/env bash
set -euo pipefail

REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
KEY_URL="https://download.nextcloud.com/office/repo/nextcloud-office.asc"
KEY_FILE="/etc/pki/rpm-gpg/RPM-GPG-KEY-nextcloud-office"
EXPECTED="C013F0BEF96800BBBC4D93DDE6E70E5FA287C3D0"
PKG="nextcloud-office-desktopeditors"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run with: sudo $0" >&2
    exit 1
fi

for cmd in curl gpg rpm dnf sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Missing command: $cmd" >&2
        exit 1
    }
done

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

curl -fsSL "$KEY_URL" -o "$TMP_KEY"

ACTUAL="$(gpg --batch --show-keys --with-colons "$TMP_KEY" |
    awk -F: '$1 == "fpr" {print toupper($10); exit}')"

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
    echo "ERROR: GPG fingerprint mismatch." >&2
    exit 1
fi

install -D -m 0644 "$TMP_KEY" "$KEY_FILE"
rpm --import "$KEY_FILE"

cat > "$REPO_FILE" <<'EOF'
[nextcloud-office]
name=Nextcloud Office
baseurl=https://download.nextcloud.com/office/repo/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-nextcloud-office
EOF

dnf clean metadata

if ! dnf -y --refresh makecache --repo=nextcloud-office; then
    echo "ERROR: Repository metadata GPG verification failed." >&2
    exit 1
fi

if rpm -q "$PKG" >/dev/null 2>&1; then
    echo "Package already installed: $PKG"
else
    dnf install -y "$PKG"
fi

echo "Done."