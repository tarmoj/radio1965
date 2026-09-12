#!/bin/bash
# Icecast <on-connect> hook (icecast.xml), run ON THE STREAMING SERVER
# itself by Icecast when a source starts broadcasting on a mountpoint
# (project-description.md #8.1/#9). Icecast passes the mountpoint as $1,
# as the literal <mount-name> string (e.g. "/user1", WITH the leading
# slash) - confirmed by testing against a live status-json.xsl capture,
# where matching without stripping it caused server_name/server_description
# to come back empty ("Unknown"/"").
#
# Publishes a type="livestream" event via the existing notification
# server API (same POST /events/publish the editor/app already use), and
# persists the created event id to a temp file keyed by channel so
# icecast_on_disconnect.sh (a separate later invocation) can unpublish it.

# link it to /user/local/bin/icecast_on_connect.sh

set -uo pipefail

CHANNEL="${1#/}"   # normalize away a leading slash, e.g. "/user1" -> "user1"
API_BASE="https://live.uuu.ee/radio1965/api"   # matches Main.qml appSettings.serverUrl default
LOGFILE="/tmp/icecast_hooks.log"

# Same reasoning as icecast_on_disconnect.sh's log() - no logging existed
# here before, so a failure to publish (or to write the id file the
# on-disconnect hook depends on) was undiagnosable after the fact.
log() { echo "$(date -Is) [on-connect] $*" >> "$LOGFILE"; }

log "invoked: mount='$1' channel='$CHANNEL'"

# Icecast fires on-connect right as it accepts the connection - possibly
# before it has finished registering the source's ice-name/ice-description
# metadata (or even the source itself) into the live registry that
# status-json.xsl reflects. Running this script manually a few seconds
# after the stream was already up never hits that race; retry briefly
# instead of querying exactly once.
SOURCE="{}"
for attempt in 1 2 3 4 5; do
  STATUS=$(curl -s "http://localhost:8001/status-json.xsl")
  # icestats.source is a single object with exactly one active source, or
  # an array with several - same defensive single-vs-list normalization as
  # server/main.py's GET /articles/{id} (Joomla's JSON:API "data" field).
  SOURCE=$(echo "$STATUS" | jq -c --arg ch "$CHANNEL" '
    (.icestats.source // empty | if type=="array" then . else [.] end)
    | map(select(.listenurl // "" | endswith("/" + $ch))) | .[0] // {}')
  if [ "$(echo "$SOURCE" | jq -r '.server_name // empty')" != "" ]; then
    break
  fi
  sleep 1
done

NAME=$(echo "$SOURCE" | jq -r '.server_name // "Unknown"')
DESCRIPTION=$(echo "$SOURCE" | jq -r '.server_description // ""')
log "resolved name='$NAME' description='$DESCRIPTION' (source='$SOURCE')"

# send_notification/save_stream (see IcecastBroadcaster::sendIcecastHandshake())
# are carried from BroadcastPage.qml's checkboxes via a single
# "ice-audio-info: send_notification=<0|1>;save_stream=<0|1>" header.
# ice-public was tried first for send_notification but doesn't survive into
# status-json.xsl at all on this Icecast setup (no <directory> block
# configured - the "public" field is simply absent from the JSON, confirmed
# via a live capture: `curl -s http://localhost:8001/status-json.xsl | jq
# '.icestats.source'`). ice-audio-info works instead because Icecast parses
# its semicolon-separated key=value pairs and hoists *every* key onto its
# own top-level field on the source object (not just its own recognized
# ones like bitrate/samplerate/channels) - so both flags come back here as
# plain integer fields, not nested inside a raw "audio_info" string. Fail
# open (send the notification) if the field is missing/unparseable, rather
# than silently swallowing notifications on a future field-name/format
# mismatch.
SEND_NOTIFICATION_RAW=$(echo "$SOURCE" | jq -r '.send_notification // empty')
SEND_NOTIFICATION="true"
if [ "$SEND_NOTIFICATION_RAW" = "0" ]; then
  SEND_NOTIFICATION="false"
fi
log "resolved send_notification='$SEND_NOTIFICATION_RAW' -> send_notification=$SEND_NOTIFICATION"

# No recording pipeline reads save_stream yet (TODOs.md "Save audio stream -
# if required"); for now it's only logged and passed through in the event
# payload so it's not lost once that pipeline exists.
SAVE_STREAM_RAW=$(echo "$SOURCE" | jq -r '.save_stream // empty')
SAVE_STREAM="false"
if [ "$SAVE_STREAM_RAW" = "1" ]; then
  SAVE_STREAM="true"
fi
log "resolved save_stream='$SAVE_STREAM_RAW' -> save_stream=$SAVE_STREAM"

BODY=$(jq -n \
  --arg name "$NAME" \
  --arg ch "$CHANNEL" \
  --arg desc "$DESCRIPTION" \
  --arg send_notification "$SEND_NOTIFICATION" \
  --argjson save_stream "$SAVE_STREAM" \
  '{
    type: "livestream",
    title: ($name + " is on air on channel " + $ch + "!"),
    summary: $desc,
    url: ("http://live.uuu.ee:8001/" + $ch),
    publish_now: true,
    send_notification: ($send_notification == "true"),
    tags: [],
    payload: {save_stream: $save_stream}
  }')

RESPONSE=$(curl -s -w '\n%{http_code}' -X POST "$API_BASE/events/publish" \
  -H "Content-Type: application/json" \
  -d "$BODY")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY_RESPONSE=$(echo "$RESPONSE" | sed '$d')
log "publish response: http=$HTTP_CODE body=$BODY_RESPONSE"

EVENT_ID=$(echo "$BODY_RESPONSE" | jq -r '.event.id // empty')
if [ -n "$EVENT_ID" ]; then
  echo "$EVENT_ID" > "/tmp/icecast_event_${CHANNEL}.id"
  log "wrote id file /tmp/icecast_event_${CHANNEL}.id (event_id='$EVENT_ID')"
else
  log "no event id in publish response - id file NOT written, on-disconnect will have nothing to unpublish"
fi