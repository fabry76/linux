#!/bin/bash

WATCH="/home/fabri/Documents"
LOCK="/tmp/rclone-sync.lock"
DEBOUNCE=10

inotifywait -r -m \
  -e create,modify,delete,move \
  --format '%e|%f' "$WATCH" |
while IFS='|' read -r event file; do

  case "$file" in
    *\.swp|*\.tmp|*\.lock|.~* ) continue ;;
  esac

  echo "Change detected: $event $file"

  NOW=$(date +%s)
  echo "$NOW" > /tmp/rclone-last-event

  (
    sleep "$DEBOUNCE"

    LAST_EVENT=$(cat /tmp/rclone-last-event 2>/dev/null || echo 0)
    NOW2=$(date +%s)

    if [ $((NOW2 - LAST_EVENT)) -ge "$DEBOUNCE" ]; then

      flock -n 9 || exit 0

      rclone sync "$WATCH" gdrive: \
        --drive-skip-gdocs \
        --exclude "*.tmp" \
        --exclude "*.swp" \
        --exclude "**/.git/**" \
        --exclude ".~lock.*" \
        --exclude "**node_modules/**" \
        --log-file "$HOME/rclone.log" \
        --log-level INFO

    fi

  ) 9>"$LOCK"

done
