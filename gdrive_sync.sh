#!/bin/bash

LOG="$HOME/rclone-upload.log"

rclone sync "$HOME/Documents" gdrive: \
  -P -v \
  --fast-list \
  2>&1 | tee "$LOG"

read -p "Sync completed. Press Enter to close..."

