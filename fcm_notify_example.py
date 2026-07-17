"""
Server-side push notifications via Firebase Cloud Messaging (FCM).

One codepath sends to both Android and iOS: FCM routes iOS-registered
tokens to APNs automatically when you include apns config in the message.

pip install firebase-admin
"""

import firebase_admin
from firebase_admin import credentials, messaging

# --- 1. Initialize once at server startup -----------------------------------

cred = credentials.Certificate("/path/to/serviceAccountKey.json")
firebase_admin.initialize_app(cred)


# --- 2. Send to a single device ----------------------------------------------

def send_single(device_token: str, title: str, body: str, event_id: str) -> str:
    """Send one notification to one device token. Returns the FCM message id."""
    message = messaging.Message(
        token=device_token,
        # Visible notification shown by the OS
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        # Data payload your app reads on tap (e.g. to deep-link to the event)
        data={
            "event_id": event_id,
            "type": "new_event",
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="new_events",  # must match a channel registered client-side
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound="default",
                    # content_available=True lets the app wake briefly to
                    # pre-fetch the event before the user taps the banner
                    content_available=True,
                ),
            ),
        ),
    )
    return messaging.send(message)


# --- 3. Send to many devices at once (up to 500 tokens per call) ------------

def send_to_many(device_tokens: list[str], title: str, body: str, event_id: str):
    """
    Broadcast to a batch of device tokens, e.g. all subscribers when a
    new event is published. Returns counts + per-token failures so you
    can prune dead tokens from your DB.
    """
    message = messaging.MulticastMessage(
        tokens=device_tokens,
        notification=messaging.Notification(title=title, body=body),
        data={"event_id": event_id, "type": "new_event"},
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(channel_id="new_events"),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", content_available=True),
            ),
        ),
    )

    # send_multicast() is deprecated — use send_each_for_multicast()
    response = messaging.send_each_for_multicast(message)

    dead_tokens = []
    for token, result in zip(device_tokens, response.responses):
        if not result.success:
            error = result.exception
            # UNREGISTERED / INVALID_ARGUMENT usually mean the token is
            # dead (app uninstalled, token rotated) — remove it from your DB
            if isinstance(error, messaging.UnregisteredError):
                dead_tokens.append(token)

    return {
        "success_count": response.success_count,
        "failure_count": response.failure_count,
        "dead_tokens": dead_tokens,
    }


# --- 4. Send by topic instead of per-token (simpler for "all subscribers") --
#
# Instead of storing every device token and batching sends yourself, clients
# can subscribe to a Firebase topic (e.g. "new_events") on the client side.
# You then send one message to the topic and Firebase fans it out.
# Trade-off: less control over delivery accounting per-user than the
# multicast approach above.

def send_to_topic(topic: str, title: str, body: str, event_id: str) -> str:
    message = messaging.Message(
        topic=topic,
        notification=messaging.Notification(title=title, body=body),
        data={"event_id": event_id, "type": "new_event"},
    )
    return messaging.send(message)


# --- 5. Example: wiring this into your Events API on publish ----------------
#
# In your Events API (e.g. FastAPI), after inserting a new/updated event
# into the DB, look up subscribed device tokens and fire the notification:
#
#   from fastapi import FastAPI
#   app = FastAPI()
#
#   @app.post("/events")
#   def create_event(event: EventIn, db: Session = Depends(get_db)):
#       new_event = crud.create_event(db, event)
#       tokens = crud.get_active_device_tokens(db)
#       if tokens:
#           result = send_to_many(
#               tokens,
#               title=new_event.title,
#               body=new_event.summary,
#               event_id=new_event.id,
#           )
#           if result["dead_tokens"]:
#               crud.remove_device_tokens(db, result["dead_tokens"])
#       return new_event
