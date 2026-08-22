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

set -uo pipefail

CHANNEL="${1#/}"   # normalize away a leading slash, e.g. "/user1" -> "user1"
API_BASE="https://live.uuu.ee/radio1965/api"
IDFILE="/tmp/icecast_event_${CHANNEL}.id"
LOGFILE="/tmp/icecast_hooks.log"

# No logging previously existed here at all - curl's response was piped to
# /dev/null and a missing id file silently no-op'd, so a failed shelve was
# indistinguishable from Icecast never invoking this hook in the first
# place. Log every step so a failure is diagnosable after the fact instead
# of only by reproducing it live with -x.
log() { echo "$(date -Is) [on-disconnect] $*" >> "$LOGFILE"; }

log "invoked: mount='$1' channel='$CHANNEL'"

if [ -f "$IDFILE" ]; then
  EVENT_ID=$(cat "$IDFILE")
  log "found id file, event_id='$EVENT_ID' - shelving"
  RESPONSE=$(curl -s -w '\n%{http_code}' -X POST "$API_BASE/events/${EVENT_ID}/shelve")
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  BODY=$(echo "$RESPONSE" | sed '$d')
  log "shelve response: http=$HTTP_CODE body=$BODY"
  rm -f "$IDFILE"
else
  log "no id file at '$IDFILE' - nothing to shelve (on-connect never ran for this channel, or already shelved/cleaned up)"
fi