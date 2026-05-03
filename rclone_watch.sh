#!/bin/bash

WATCH="/home/fabri/Documents"
LOCK="/tmp/rclone-bisync.lock"

while true; do
  # 👀 aspetta eventi ricorsivi (anche cartelle vuote incluse)
 inotifywait -r -m -e create,modify,delete,move /home/fabri/Documents

  # 🧠 debounce (evita spam di sync)
  sleep 10

  # 🔒 evita doppie esecuzioni
  flock -n "$LOCK" /usr/bin/rclone bisync "$WATCH" gdrive: \
    --check-first \
    --drive-skip-gdocs \
    --backup-dir gdrive:Documents_backup \
    --log-file /home/fabri/rclone.log \
    --log-level INFO

done
