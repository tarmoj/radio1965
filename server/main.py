"""
Minimal FastAPI server exposing FCM push notification endpoints.

Run from the repo root with:
    SEND_TEST_NOTIFICATION=1 uvicorn server.main:app --reload
"""

import logging
import time
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from server import config, notifications

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Radio 1965 Notification Service")

# Dev-only: allows the test client (client/index.html), served from a
# different origin/port, to call this API. Restrict this before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def testNotification() -> None:
    """Send a test push notification to the TEST_TOPIC. Logs the result."""
    try:
        message_id = notifications.send_to_topic(
            topic=config.TEST_TOPIC,
            title="Test notification",
            body="Radio 1965 test notification",
            event_id="test",
        )
        logger.info("Test notification sent to topic '%s': %s", config.TEST_TOPIC, message_id)
    except Exception:
        logger.exception("Failed to send test notification to topic '%s'", config.TEST_TOPIC)


@app.on_event("startup")
def on_startup() -> None:
    notifications.init_firebase()
    if config.SEND_TEST_NOTIFICATION:
        testNotification()
    else:
        logger.info("Test notification skipped (set SEND_TEST_NOTIFICATION=1 to enable)")


class TopicNotificationRequest(BaseModel):
    topic: str
    title: str
    body: str
    event_id: str


class MulticastNotificationRequest(BaseModel):
    tokens: list[str]
    title: str
    body: str
    event_id: str


class SubscribeRequest(BaseModel):
    token: str
    topic: str


# Mirrors the Event JSON schema in project-description.md. All fields other
# than title/summary have sensible defaults so the editor page only needs
# to send title, summary and the article text (as payload.text) - the rest
# is filled in automatically here.
class EventIn(BaseModel):
    id: str | None = None
    type: str = "article"
    title: str
    summary: str
    url: str = ""
    thumbnail_url: str = ""
    status: str = "live"
    starts_at: str | None = None
    ends_at: str = ""
    source: str = "native"
    source_ref: str = ""
    tags: list[str] = Field(default_factory=list)
    payload: dict = Field(default_factory=dict)
    comments_enabled: bool = True


@app.post("/notify/topic")
def notify_topic(req: TopicNotificationRequest):
    message_id = notifications.send_to_topic(req.topic, req.title, req.body, req.event_id)
    return {"message_id": message_id}


@app.post("/notify/multicast")
def notify_multicast(req: MulticastNotificationRequest):
    return notifications.send_to_many(req.tokens, req.title, req.body, req.event_id)


@app.post("/notify/test")
def notify_test():
    testNotification()
    return {"status": "sent"}


@app.post("/devices/subscribe")
def subscribe_device(req: SubscribeRequest):
    response = notifications.subscribe_to_topic([req.token], req.topic)
    return {"success_count": response.success_count, "failure_count": response.failure_count}


@app.post("/events/publish")
def publish_event(event: EventIn):
    """
    Build a full Event JSON object (schema in project-description.md) from
    the editor's input and immediately push a notification for it to
    TEST_TOPIC. Storage in an Events DB is not implemented yet - this is
    notification-only, per the current scope.
    """
    event_dict = event.model_dump()
    if not event_dict["id"]:
        event_dict["id"] = f"evt_{int(time.time() * 1000)}"
    if not event_dict["starts_at"]:
        event_dict["starts_at"] = datetime.now(timezone.utc).isoformat()

    message_id = notifications.send_event_notification(event_dict, config.TEST_TOPIC)
    return {"event": event_dict, "message_id": message_id}
