#!/bin/bash
# Icecast <on-disconnect> hook (icecast.xml), run ON THE STREAMING SERVER
# by Icecast when a source stops broadcasting on a mountpoint
# (project-description.md #8.1/#9). Icecast passes the mountpoint as $1,
# as the literal <mount-name> string (e.g. "/user1", WITH the leading
# slash) - see server/icecast_on_connect.sh for how this was confirmed.
# Must normalize the same way here too, since the id-file path built below
# has to match the one icecast_on_connect.sh wrote.
#
# Shelves the event server/icecast_on_connect.sh created for this channel,
# via the new POST /events/{id}/shelve (server/main.py) - immediate,
# rather than waiting on cron_publish.py's time-based shelf_at sweep.

# link it to /usr/local/bin

set -euo pipefail

CHANNEL="${1#/}"   # normalize away a leading slash, e.g. "/user1" -> "user1"
API_BASE="https://live.uuu.ee/radio1965/api"
IDFILE="/tmp/icecast_event_${CHANNEL}.id"

if [ -f "$IDFILE" ]; then
  EVENT_ID=$(cat "$IDFILE")
  curl -s -X POST "$API_BASE/events/${EVENT_ID}/shelve" > /dev/null
  rm -f "$IDFILE"
fi