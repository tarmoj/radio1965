"""
Minimal FastAPI server exposing FCM push notification endpoints.

Run from the repo root with:
    SEND_TEST_NOTIFICATION=1 uvicorn server.main:app --reload
"""

import logging

from fastapi import FastAPI
from pydantic import BaseModel

from server import config, notifications

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Radio 1965 Notification Service")


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
