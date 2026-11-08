#!/bin/bash

###############################################
# Configuration
###############################################
WATCH="$HOME/Documents"            # Local folder to watch and sync to Google Drive
LOCK="/tmp/rclone-sync.lock"       # Lock file to prevent concurrent rclone runs
STAMP="/tmp/rclone-last-event"     # Stores the timestamp of the last detected change
LOGFILE="$HOME/rclone.log"         # rclone log (reset at startup, appended afterwards)
DEBOUNCE=10                        # Seconds of inactivity to wait before syncing

###############################################
# Sync function
###############################################
# Runs rclone inside a lock. The blocking flock makes any concurrent
# call wait for the running sync to finish instead of being discarded,
# so no change is ever lost.
do_sync() {
  (
    flock 9
    rclone sync "$WATCH" gdrive: \
      --drive-skip-gdocs \
      --exclude "*.tmp" \
      --exclude "*.swp" \
      --exclude "**/.git/**" \
      --exclude ".~lock.*" \
      --exclude "**node_modules/**" \
      --log-file "$LOGFILE" \
      --log-level INFO
  ) 9>"$LOCK"
}

###############################################
# Startup
###############################################
# Overwrite the log once, when the service starts.
# Afterwards rclone appends to it for the rest of the session.
echo "$(date '+%Y/%m/%d %H:%M:%S') INFO  : rclone-sync service started" > "$LOGFILE"

# Initial sync at startup. Retry until it succeeds, because the
# network may not be ready yet right after boot. This also guarantees
# that the log gets a "Transferred / Checks" block on every start,
# even when there is nothing to upload.
until do_sync; do
  echo "Initial sync failed, retrying in 15s..."
  sleep 15
done

###############################################
# Watcher
###############################################
# Watch the folder recursively and react to file events.
# .git and node_modules are ignored at the inotify level.
inotifywait -r -m \
  -e create,modify,delete,move \
  --exclude '(^|/)(\.git|node_modules)(/|$)' \
  --format '%e|%f' "$WATCH" |
while IFS='|' read -r event file; do

  # Ignore temporary and lock files
  case "$file" in
    *.swp|*.tmp|*.lock|.~* ) continue ;;
  esac

  # Messages printed here end up in the journal, not in rclone.log
  echo "Change detected: $event $file"

  # Record the time of the latest event
  date +%s > "$STAMP"

  # Debounce: wait, then sync only if no newer event arrived meanwhile.
  # Runs in the background so the watcher loop keeps reading events.
  (
    sleep "$DEBOUNCE"
    LAST_EVENT=$(cat "$STAMP" 2>/dev/null || echo 0)
    if [ $(( $(date +%s) - LAST_EVENT )) -ge "$DEBOUNCE" ]; then
      do_sync
    fi
  ) &

done