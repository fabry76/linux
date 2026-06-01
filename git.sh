#!/bin/bash

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
# Configuration
###############################################
REPO_PATH="$HOME/Git/linux"
SOURCE_KEY="$HOME/Fastgate/Varie/id_ed25519"
DEST_KEY="$HOME/.ssh/id_ed25519"
REMOTE_URL="git@github.com:fabry76/linux.git"

###############################################
# Fastgate check
###############################################
if [ ! -f "$SOURCE_KEY" ]; then
  echo
  echo "SSH key not found:"
  echo "$SOURCE_KEY"
  echo
  echo "Fastgate share is probably not mounted."
  exit 1
fi

###############################################
# Repository
###############################################
cd "$REPO_PATH" || {
echo "Error: repository not found at $REPO_PATH"
exit 1
}

echo "Now inside repository: $(pwd)"

###############################################
# SSH Directory
###############################################
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

###############################################
# SSH Config
###############################################
SSH_CONFIG_CONTENT='Host github.com
HostName github.com
User git
IdentityFile ~/.ssh/id_ed25519
AddKeysToAgent yes'

write_if_changed "$HOME/.ssh/config" "$SSH_CONFIG_CONTENT"
chmod 600 "$HOME/.ssh/config"

###############################################
# Known Hosts
###############################################
touch "$HOME/.ssh/known_hosts"
chmod 644 "$HOME/.ssh/known_hosts"

if ! ssh-keygen -F github.com >/dev/null; then
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo "GitHub host key added to known_hosts"
fi

###############################################
# SSH Key
###############################################
if [ ! -f "$DEST_KEY" ]; then
cp "$SOURCE_KEY" "$DEST_KEY"
chmod 600 "$DEST_KEY"
echo "SSH key copied successfully"
fi

###############################################
# Git Configuration
###############################################
git config --global user.name "fabry76"
git config --global user.email "fabrizio.fabiani@gmail.com"

###############################################
# Git Remote
###############################################
git remote set-url origin "$REMOTE_URL"

###############################################
# SSH Agent
###############################################
if [ -n "$SSH_AUTH_SOCK" ]; then
ssh-add -l >/dev/null 2>&1 || ssh-add "$DEST_KEY"
fi

###############################################
# Verification
###############################################
ssh-add -l

echo "Git SSH setup completed successfully."
