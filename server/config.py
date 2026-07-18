"""
Server configuration.

Kept intentionally minimal for now - as the Events API grows, this can be
replaced with pydantic-settings or similar.
"""

import os

# Path to the Firebase service account key (JSON). Not committed to git -
# see .gitignore. Place your real key file at this location.
FIREBASE_CRED_PATH = "server/config/serviceAccountKey.json"

# When set to "1", a test push notification is sent to TEST_TOPIC on
# server startup. Defaults to off so restarts don't spam subscribers.
SEND_TEST_NOTIFICATION = os.getenv("SEND_TEST_NOTIFICATION") == "1"

# FCM topic used by testNotification(). Clients subscribe to this topic to
# receive the test push.
TEST_TOPIC = "radio65_event"
