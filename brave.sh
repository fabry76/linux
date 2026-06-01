TMP_BRAVE_KEY="$(mktemp)"

curl -fsSL \
  https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
  -o "$TMP_BRAVE_KEY"

if [ ! -f /etc/apt/keyrings/brave-browser-archive-keyring.gpg ] || \
   ! cmp -s "$TMP_BRAVE_KEY" /etc/apt/keyrings/brave-browser-archive-keyring.gpg; then
  install -m 0644 "$TMP_BRAVE_KEY" /etc/apt/keyrings/brave-browser-archive-keyring.gpg
fi

rm -f "$TMP_BRAVE_KEY"

write_if_changed /etc/apt/sources.list.d/brave-browser.sources "$(cat << 'EOF'
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64 arm64
Signed-By: /etc/apt/keyrings/brave-browser-archive-keyring.gpg
EOF
)"