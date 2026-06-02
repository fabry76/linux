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
# Repository
###############################################

TMP_VSCODE_KEY="$(mktemp)"

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
gpg --batch --yes --dearmor --output "$TMP_VSCODE_KEY"

if [ ! -f /etc/apt/keyrings/microsoft-vscode.gpg ] || \
   ! cmp -s "$TMP_VSCODE_KEY" /etc/apt/keyrings/microsoft-vscode.gpg; then
  install -m 0644 "$TMP_VSCODE_KEY" /etc/apt/keyrings/microsoft-vscode.gpg
fi

rm -f "$TMP_VSCODE_KEY"

write_if_changed /etc/apt/sources.list.d/vscode.sources "$(cat << 'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/microsoft-vscode.gpg
EOF
)"

###############################################
# Installation
###############################################

apt-get update
apt-get install -y code
