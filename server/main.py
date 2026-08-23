"""
Minimal FastAPI server exposing FCM push notification endpoints.

Run from the repo root with:
    source server/set_env.sh
    SEND_TEST_NOTIFICATION=1 uvicorn server.main:app --reload
"""

import logging
import re
import time
from datetime import datetime, timedelta
from urllib.parse import urljoin

import requests
from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from server import config, db, joomla_importer, notifications

# Minimal responsive wrapper for Joomla's article "text" field (a bare HTML
# fragment with no viewport meta/CSS of its own) - see GET /articles/{id}.
ARTICLE_HTML_TEMPLATE = """<!doctype html><html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{{font-family:sans-serif;padding:8px}}img,video,iframe{{max-width:100%;height:auto}}</style>
</head><body>{body}</body></html>"""

# Matches src="..."/href="..." (single or double quotes) whose value isn't
# already absolute (http(s)://, data:, or a #fragment).
_RELATIVE_URL_ATTR = re.compile(r"""(src|href)=(["'])(?!https?://|data:|#)([^"']+)\2""", re.IGNORECASE)


def _absolutize_urls(html: str, base: str) -> str:
    """
    Rewrite relative src/href attributes (e.g. Joomla's "images/foo.jpg") to
    absolute URLs against `base`. WebView.loadHtml(html, baseUrl)'s own
    relative-URL resolution is what this replaces - it's unreliable on the
    Android WebView backend, which has shown percent-encoded content instead
    of rendering it when a baseUrl is passed (desktop is unaffected, so this
    is worked around at the content level instead of relying on the
    platform's loadHtml() implementation).
    """
    return _RELATIVE_URL_ATTR.sub(lambda m: f'{m.group(1)}={m.group(2)}{urljoin(base, m.group(3))}{m.group(2)}', html)

# Events default to being moved to the shelf a week after publish_at if the
# editor doesn't set an explicit shelf_at (see project-description.md #7).
DEFAULT_SHELF_DELAY = timedelta(days=7)


def _parse_datetime(value: str) -> datetime:
    """
    Parse a datetime string from the editor's <input type="datetime-local">
    (e.g. '2026-08-01T14:24') as naive local time - matching the server's
    own local clock, so it can be compared directly with datetime.now().
    """
    return datetime.fromisoformat(value)

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
    db.Base.metadata.create_all(bind=db.engine)
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


# Mirrors the Event JSON schema (v2) + editor spec (project-description.md
# #4, #7). `status` is not client-settable - the server derives it from
# publish_now/publish_at (see publish_event()). Fields not in the v2 draft
# (e.g. source/source_ref for the future Joomla importer, or per-type extras
# like stream server address) should be nested inside payload instead of
# added here.
class EventIn(BaseModel):
    id: str | None = None
    type: str = "article"
    title: str
    summary: str
    url: str = ""
    publish_at: str | None = None
    publish_now: bool = False
    shelf_at: str | None = None
    tags: list[str] = Field(default_factory=list)
    payload: dict = Field(default_factory=dict)
    comments_enabled: bool = False
    # Opt out of the push while still publishing/listing the event - used by
    # server/icecast_on_connect.sh, forwarding BroadcastPage.qml's "Send
    # notification" checkbox (see IcecastBroadcaster::startBroadcast()).
    send_notification: bool = True


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
def publish_event(event: EventIn, session: Session = Depends(db.get_db)):
    """
    Build a full Event JSON object (schema in project-description.md),
    persist it (+ its tags) to the Events DB.

    If publish_now is set (or no publish_at was given), the event is
    published immediately: status is set to 'new' and the FCM
    notification is sent right away. Otherwise the event is stored as
    'unpublished' and server/cron_publish.py (run every minute) sends the
    notification and flips it to 'new' once publish_at has passed, and
    later to 'shelved' once shelf_at has passed - see project-description.md
    #5 and #7.
    """
    event_id = event.id or f"evt_{int(time.time() * 1000)}"

    now = datetime.now()
    if event.publish_now or not event.publish_at:
        publish_at = now
        status = "new"
    else:
        publish_at = _parse_datetime(event.publish_at)
        status = "unpublished"

    shelf_at = _parse_datetime(event.shelf_at) if event.shelf_at else publish_at + DEFAULT_SHELF_DELAY

    row = db.Event(
        id=event_id,
        type=event.type,
        title=event.title,
        summary=event.summary,
        url=event.url,
        publish_at=publish_at,
        shelf_at=shelf_at,
        status=status,
        comments_enabled=event.comments_enabled,
        payload=event.payload,
        tags=[db.Tag(tag=tag) for tag in event.tags],
    )
    session.add(row)
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        raise HTTPException(status_code=409, detail=f"Event '{event_id}' already exists")
    session.refresh(row)

    event_dict = row.to_dict()
    message_id = None
    if status == "new" and event.send_notification:
        message_id = notifications.send_event_notification(event_dict, config.TEST_TOPIC)

    return {"event": event_dict, "message_id": message_id, "sent_immediately": status == "new"}


@app.post("/events/{event_id}/unpublish")
def unpublish_event(event_id: str, session: Session = Depends(db.get_db)):
    """
    Immediately moves an event to 'unpublished' - used by
    server/icecast_on_disconnect.sh (project-description.md #8.1/#9) so a
    livestream event disappears from both "New Arrivals" and "Collection"
    (list_events() only shows status new/shelved by default) the moment the
    broadcaster actually disconnects, rather than lingering as a "shelved"
    (archived-but-visible) entry - an ended broadcast isn't a collectible
    item like a finished audio/video, it's just over.
    """
    row = session.get(db.Event, event_id)
    if row is None:
        raise HTTPException(status_code=404, detail=f"Event '{event_id}' not found")
    row.status = "unpublished"
    session.commit()
    return {"event": row.to_dict()}


@app.get("/events")
def list_events(status: list[str] | None = Query(None), session: Session = Depends(db.get_db)):
    """
    Feed for the client app (project-description.md #2.1): "New Arrivals"
    (status=new) and "Collection" (status=shelved) by default, since
    unpublished events aren't due yet and archived ones are dropped from
    both. Pass ?status=... (repeatable) to override.
    """
    query = session.query(db.Event)
    query = query.filter(db.Event.status.in_(status or ["new", "shelved"]))
    rows = query.order_by(db.Event.publish_at.desc()).limit(200).all()
    return {"events": [r.to_dict() for r in rows]}


@app.get("/articles/{article_id}")
def get_article(article_id: int):
    """
    Proxy for a single Joomla article's HTML content (project-description.md
    #2). The app never holds JOOMLA_API_TOKEN - it calls this instead of
    Joomla directly, same auth/base URL as server/joomla_importer.py.
    Content is fetched live on every call, never stored server-side.
    """
    try:
        resp = requests.get(
            f"{joomla_importer.JOOMLA_BASE_URL}/content/articles/{article_id}",
            headers=joomla_importer.HEADERS,
            timeout=30,
        )
    except requests.RequestException:
        raise HTTPException(status_code=502, detail="Failed to reach Joomla")

    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail=f"Article {article_id} not found")
    try:
        resp.raise_for_status()
    except requests.RequestException:
        raise HTTPException(status_code=502, detail="Failed to fetch article from Joomla")

    data = resp.json().get("data")
    if isinstance(data, list):
        data = data[0] if data else None
    if not data:
        raise HTTPException(status_code=404, detail=f"Article {article_id} not found")

    attrs = data["attributes"]
    # Same fallback chain as joomla_importer.joomla_article_to_event().
    body_html = attrs.get("text") or attrs.get("introtext") or attrs.get("fulltext") or ""
    # Site root, not attrs["link"]: Joomla's relative asset paths (e.g.
    # "images/foo.jpg") resolve against the site root, not the article's own
    # permalink path.
    base_url = joomla_importer.JOOMLA_SITE_URL
    body_html = _absolutize_urls(body_html, base_url)

    return {
        "article_id": article_id,
        "title": attrs.get("title", ""),
        "html": ARTICLE_HTML_TEMPLATE.format(body=body_html),
        "base_url": base_url,
    }


@app.get("/tags")
def list_tags(q: str = "", limit: int = 20, session: Session = Depends(db.get_db)):
    """
    Distinct tags for the editor's tag autocomplete (project-description.md
    #7: "suggest existing tags" as the user types).
    """
    query = session.query(db.Tag.tag).distinct()
    if q:
        query = query.filter(db.Tag.tag.ilike(f"{q}%"))
    rows = query.order_by(db.Tag.tag).limit(limit).all()
    return {"tags": [r[0] for r in rows]}
