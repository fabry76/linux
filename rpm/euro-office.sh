#!/usr/bin/env bash
set -euo pipefail

# Repository configuration
REPO_FILE="/etc/yum.repos.d/nextcloud-office.repo"
REPO_ID="nextcloud-office"
GPG_KEY="https://download.nextcloud.com/office/repo/nextcloud-office.asc"
EXPECTED_FINGERPRINT="C013F0BEF96800BBBC4D93DDE6E70E5FA287C3D0"

# Package name
PKG="nextcloud-office-desktopeditors"

# 1) Check for root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0" >&2
    exit 1
fi

# 2) Download and verify the repository signing key
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
    echo "Actual:   ${ACTUAL_FINGERPRINT:-unavailable}" >&2
    exit 1
fi

# 3) Import the verified key without interactive prompts
rpm --import "$TMP_KEY"
echo "Repository signing key verified and imported."

# 4) Configure the repository
cat > "$REPO_FILE" <<EOF
[$REPO_ID]
name=Nextcloud Office
baseurl=https://download.nextcloud.com/office/repo/rpm/stable/\\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$GPG_KEY
EOF

echo "Repository configuration created."

# 5) Refresh repository metadata automatically
dnf -y makecache --refresh

# 6) Install the package if it is not already installed
if ! rpm -q "$PKG" &>/dev/null; then
    dnf install -y "$PKG"
    echo "Package installed: $PKG"
else
    echo "Package already installed: $PKG"
fi

echo "Done."