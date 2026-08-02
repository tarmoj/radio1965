"""
Every-minute cron job: sends notifications for events whose publish_at has
passed and are still 'unpublished', and moves 'new' events whose
shelf_at has passed to 'shelfed' (project-description.md #5 and #7).

Run directly against the DB/FCM (no dependency on the API server being up).

Install via crontab (adjust paths for your deployment):
    * * * * * cd /home/pierre/src/radio1965 && . server/set_env.sh && /home/pierre/src/radio1965/server/.venv/bin/python -m server.cron_publish >> /var/log/radio65_cron.log 2>&1
"""

import logging
from datetime import datetime

from server import config, db, notifications

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def publish_due_events(session) -> None:
    """unpublished -> new: send the FCM notification, then flip status."""
    now = datetime.now()
    due = (
        session.query(db.Event)
        .filter(db.Event.status == "unpublished", db.Event.publish_at <= now)
        .all()
    )
    for event in due:
        try:
            notifications.send_event_notification(event.to_dict(), config.TEST_TOPIC)
            event.status = "new"
            session.commit()
            logger.info("Published event '%s' (sent notification, status -> new)", event.id)
        except Exception:
            session.rollback()
            logger.exception("Failed to publish event '%s'", event.id)


def shelf_due_events(session) -> None:
    """new -> shelfed: no notification, just a status change."""
    now = datetime.now()
    due = (
        session.query(db.Event)
        .filter(db.Event.status == "new", db.Event.shelf_at.isnot(None), db.Event.shelf_at <= now)
        .all()
    )
    for event in due:
        try:
            event.status = "shelfed"
            session.commit()
            logger.info("Shelved event '%s' (status -> shelfed)", event.id)
        except Exception:
            session.rollback()
            logger.exception("Failed to shelve event '%s'", event.id)


def main() -> None:
    notifications.init_firebase()
    session = db.SessionLocal()
    try:
        publish_due_events(session)
        shelf_due_events(session)
    finally:
        session.close()


if __name__ == "__main__":
    main()
