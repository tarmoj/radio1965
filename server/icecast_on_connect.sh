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
# icecast_on_disconnect.sh (a separate later invocation) can shelve it.

# link it to /user/local/bin/icecast_on_connect.sh

set -euo pipefail

CHANNEL="${1#/}"   # normalize away a leading slash, e.g. "/user1" -> "user1"
API_BASE="https://live.uuu.ee/radio1965/api"   # matches Main.qml appSettings.serverUrl default

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

BODY=$(jq -n \
  --arg name "$NAME" \
  --arg ch "$CHANNEL" \
  --arg desc "$DESCRIPTION" \
  '{
    type: "livestream",
    title: ($name + " is on air on channel " + $ch + "!"),
    summary: $desc,
    url: ("http://live.uuu.ee:8001/" + $ch),
    publish_now: true,
    tags: [],
    payload: {}
  }')

RESPONSE=$(curl -s -X POST "$API_BASE/events/publish" \
  -H "Content-Type: application/json" \
  -d "$BODY")

EVENT_ID=$(echo "$RESPONSE" | jq -r '.event.id // empty')
if [ -n "$EVENT_ID" ]; then
  echo "$EVENT_ID" > "/tmp/icecast_event_${CHANNEL}.id"
fi