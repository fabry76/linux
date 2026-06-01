TMP_MOZILLA_KEY="$(mktemp)"

curl -fsSL \
  https://packages.mozilla.org/apt/repo-signing-key.gpg \
  -o "$TMP_MOZILLA_KEY"

if [ ! -f /etc/apt/keyrings/mozilla.gpg ] || \
   ! cmp -s "$TMP_MOZILLA_KEY" /etc/apt/keyrings/mozilla.gpg; then
  install -m 0644 "$TMP_MOZILLA_KEY" /etc/apt/keyrings/mozilla.gpg
fi

rm -f "$TMP_MOZILLA_KEY"

write_if_changed /etc/apt/sources.list.d/mozilla.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/mozilla.gpg
EOF
)"