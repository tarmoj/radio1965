"""
Joomla -> Events DB importer example script from claude.io.

Run on a schedule (cron, or apscheduler inside the FastAPI app) to poll
Joomla's Web Services API for published/updated articles and upsert them
into the Events table as type="article", source="joomla_import".

pip install requests sqlalchemy

don't forget 'source server/set_env.sh'
"""

import json
import os
import re
from datetime import datetime, timezone

import requests

JOOMLA_BASE_URL = "https://eccm.ee/api/index.php/v1"
JOOMLA_API_TOKEN = os.getenv("JOOMLA_API_TOKEN")
JOOMLA_CATEGORY_ID = 47  # set to restrict import to one category, or leave None for all

HEADERS = {
    "Authorization": f"Bearer {JOOMLA_API_TOKEN}",
    "Accept": "application/vnd.api+json",
}


def strip_html(html: str, max_len: int = 400) -> str:
    """Very small HTML-tag stripper for building a plain-text summary."""
    text = re.sub(r"<[^>]+>", "", html or "")
    text = re.sub(r"\s+", " ", text).strip()
    return text[:max_len]


def fetch_articles(modified_since: datetime | None = None) -> list[dict]:
    """Fetch published articles from Joomla, optionally filtered by modified date."""
    params = {
        "filter[state]": "1",           # published only
        "list[fullordering]": "a.modified DESC",
        "list[limit]": "100",
    }
    if JOOMLA_CATEGORY_ID:
        params["filter[category]"] = JOOMLA_CATEGORY_ID

    resp = requests.get(f"{JOOMLA_BASE_URL}/content/articles", headers=HEADERS, params=params, timeout=30)
    resp.raise_for_status()
    body = resp.json()

    articles = []
    for item in body.get("data", []):
        attrs = item["attributes"]

        # Don't trust the server-side filter alone - Joomla's API has had
        # bugs where combined filter[] params silently drop one another.
        cat_id = item.get("relationships", {}).get("category", {}).get("data", {}).get("id")
        if str(cat_id) != str(JOOMLA_CATEGORY_ID):
            continue
        if attrs.get("state") != 1:
            continue

        modified = datetime.fromisoformat(attrs["modified"]).replace(tzinfo=timezone.utc)
        if modified_since and modified <= modified_since:
            continue

        articles.append(item)

    return articles


def joomla_article_to_event(item: dict) -> dict:
    """Map a Joomla article's JSON:API record to our Events schema."""
    attrs = item["attributes"]
    article_id = item["id"]

    # images comes back as a JSON-encoded string, not a nested object
    images = {}
    if attrs.get("images"):
        try:
            images = json.loads(attrs["images"])
        except (json.JSONDecodeError, TypeError):
            images = {}

    return {
        "id": f"joomla_{article_id}",
        "type": "article",
        "title": attrs["title"],
        "summary": strip_html(attrs.get("introtext", "")),
        "url": attrs.get("link") or f"https://yourjoomlasite.com/index.php?option=com_content&id={article_id}",
        "thumbnail_url": images.get("image_intro") or None,
        "status": "past",  # articles aren't "upcoming" the way scheduled streams are
        "starts_at": attrs["created"],
        "ends_at": None,
        "source": "joomla_import",
        "source_ref": str(article_id),
        "payload": {},
        "comments_enabled": True,
    }


def run_import(db_session, last_sync: datetime | None):
    """
    db_session: your SQLAlchemy session (or swap for raw DB calls).
    last_sync: timestamp of the previous successful run, stored wherever
               you keep small app state (a settings table, a file, etc).
    """
    articles = fetch_articles(modified_since=last_sync)
    new_or_updated_events = []

    for item in articles:
        event = joomla_article_to_event(item)
        # Upsert by (source, source_ref) - pseudocode, adapt to your ORM:
        #
        # existing = db_session.query(Event).filter_by(
        #     source="joomla_import", source_ref=event["source_ref"]
        # ).first()
        # if existing:
        #     for k, v in event.items():
        #         setattr(existing, k, v)
        # else:
        #     db_session.add(Event(**event))
        #     new_or_updated_events.append(event)  # only notify for genuinely new ones

    db_session.commit()

    # Trigger push notifications for newly-imported articles only
    # (reuse send_to_many() from the earlier FCM example)
    # for event in new_or_updated_events:
    #     send_to_many(subscribed_tokens, event["title"], event["summary"], event["id"])

    return datetime.now(timezone.utc)  # new last_sync value to persist

#test
print(fetch_articles())