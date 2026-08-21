#!/usr/bin/env bash
set -euo pipefail

# URL of the Brave browser repository file
REPO_URL="https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo"

# Expected repository ID used by DNF
REPO_ID="brave-browser"

# Package name to install
PKG="brave-origin"

# 1) Idempotent repository setup
# Check whether the repository is already enabled in DNF
if ! dnf repolist --enabled | awk '{print $1}' | grep -qx "$REPO_ID"; then
  # Add repository only if it does not exist
  dnf config-manager addrepo --from-repofile="$REPO_URL"

  # Refresh metadata after adding the repo
  dnf makecache --refresh

  echo "Repository added"
else
  echo "Repository already present"
fi

# 2) Idempotent package installation
# Check whether the package is already installed
if ! rpm -q "$PKG" &>/dev/null; then
  # Install package only if missing
  dnf install -y "$PKG"
else
  echo "Package already installed: $PKG"
fi
