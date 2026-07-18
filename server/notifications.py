"""
Push notifications via Firebase Cloud Messaging (FCM).

One codepath sends to both Android and iOS: FCM routes iOS-registered
tokens to APNs automatically when apns config is included in the message.

Adapted from fcm_notify_example.py.
"""

import logging

import firebase_admin
from firebase_admin import credentials, messaging

from server import config

logger = logging.getLogger(__name__)


def init_firebase() -> None:
    """Initialize the Firebase app once. Safe to call multiple times."""
    if firebase_admin._apps:
        return
    cred = credentials.Certificate(config.FIREBASE_CRED_PATH)
    firebase_admin.initialize_app(cred)


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

    # send_multicast() is deprecated - use send_each_for_multicast()
    response = messaging.send_each_for_multicast(message)

    dead_tokens = []
    for token, result in zip(device_tokens, response.responses):
        if not result.success:
            error = result.exception
            # UNREGISTERED / INVALID_ARGUMENT usually mean the token is
            # dead (app uninstalled, token rotated) - remove it from your DB
            if isinstance(error, messaging.UnregisteredError):
                dead_tokens.append(token)

    return {
        "success_count": response.success_count,
        "failure_count": response.failure_count,
        "dead_tokens": dead_tokens,
    }


def send_to_topic(topic: str, title: str, body: str, event_id: str) -> str:
    """
    Send to all clients subscribed to a Firebase topic instead of batching
    per-token sends. Simpler for "all subscribers" but gives less
    delivery accounting than send_to_many().
    """
    message = messaging.Message(
        topic=topic,
        notification=messaging.Notification(title=title, body=body),
        data={"event_id": event_id, "type": "new_event"},
    )
    return messaging.send(message)


def subscribe_to_topic(tokens: list[str], topic: str):
    """
    Subscribe device tokens to a topic so send_to_topic() reaches them.
    Called from the client once it has obtained its own FCM token (see
    client/index.html), since topic subscription is keyed by token, not
    by anything the server generates itself.
    """
    return messaging.subscribe_to_topic(tokens, topic)
