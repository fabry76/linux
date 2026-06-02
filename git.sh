#!/bin/bash
set -euo pipefail

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
# Repository (auto-clone if missing)
###############################################
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Repository not found, cloning..."

    mkdir -p "$(dirname "$REPO_PATH")"
    git clone "$REMOTE_URL" "$REPO_PATH"
fi

cd "$REPO_PATH"
echo "Inside repository: $(pwd)"

###############################################
# SSH directory
###############################################
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

###############################################
# SSH config
###############################################
SSH_CONFIG_CONTENT='Host github.com
HostName github.com
User git
IdentityFile ~/.ssh/id_ed25519
IdentitiesOnly yes'

write_if_changed "$HOME/.ssh/config" "$SSH_CONFIG_CONTENT"
chmod 600 "$HOME/.ssh/config"

###############################################
# Known hosts
###############################################
touch "$HOME/.ssh/known_hosts"
chmod 644 "$HOME/.ssh/known_hosts"

if ! ssh-keygen -F github.com >/dev/null; then
    ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    echo "GitHub host key added"
fi

###############################################
# SSH KEY (NO PASSPHRASE)
###############################################
if [ ! -f "$DEST_KEY" ] || ! cmp -s "$SOURCE_KEY" "$DEST_KEY"; then
    cp "$SOURCE_KEY" "$DEST_KEY"
    chmod 600 "$DEST_KEY"
    echo "SSH key installed/updated (no passphrase)"
fi

###############################################
# Git config
###############################################
git config --global user.name "fabry76"
git config --global user.email "fabrizio.fabiani@gmail.com"

###############################################
# Remote setup
###############################################
if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi

###############################################
# Test SSH (non interactive)
###############################################
echo "Testing SSH connection..."
ssh -o BatchMode=yes -T git@github.com || true

###############################################
# Done
###############################################
echo "Git setup completed successfully"