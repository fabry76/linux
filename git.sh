###############################################
# Repository check
###############################################
if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Error: not a git repository: $REPO_PATH"
    exit 1
fi

cd "$REPO_PATH"

###############################################
# SSH KEY (NO ENCRYPTION)
###############################################
if [ ! -f "$DEST_KEY" ] || ! cmp -s "$SOURCE_KEY" "$DEST_KEY"; then
    cp "$SOURCE_KEY" "$DEST_KEY"
    chmod 600 "$DEST_KEY"
    echo "SSH key installed/updated"
fi

###############################################
# Remote
###############################################
if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi