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

# MySQL/MariaDB connection URL for the Events DB (see sql/schema.sql). Not
# committed to git - set it via env var, e.g. `source server/set_env.sh`
# (see server/set_env.sh, gitignored) before starting the server.
try:
    DATABASE_URL = os.environ["RADIO65_DATABASE_URL"]
except KeyError as exc:
    raise RuntimeError(
        "RADIO65_DATABASE_URL is not set. Run `source server/set_env.sh` "
        "(create it from your own credentials, see sql/schema.sql) before "
        "starting the server."
    ) from exc
