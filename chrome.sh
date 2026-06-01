TMP_CHROME_KEY="$(mktemp)"

curl -fsSL \
  https://dl.google.com/linux/linux_signing_key.pub \
  -o "$TMP_CHROME_KEY"

if [ ! -f /etc/apt/keyrings/google-chrome.asc ] || \
   ! cmp -s "$TMP_CHROME_KEY" /etc/apt/keyrings/google-chrome.asc; then
  install -m 0644 "$TMP_CHROME_KEY" /etc/apt/keyrings/google-chrome.asc
fi

rm -f "$TMP_CHROME_KEY"

write_if_changed /etc/apt/sources.list.d/google-chrome.sources "$(cat << 'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.asc
EOF
)"