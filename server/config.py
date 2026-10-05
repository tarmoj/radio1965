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

# Plain-text file holding the current "Temporary contributor" password
# (project-description.md #10.1) - deliberately NOT hashed/encrypted, so an
# admin can just open the file and replace the password directly. Protect
# it via filesystem permissions instead (e.g. chmod 600, owned by whatever
# user runs this server) rather than via encryption. Read fresh on every
# request (see main.py's verify_temporary_contributor_password()), so an
# edit takes effect immediately without restarting the server.
TEMPORARY_CONTRIBUTOR_PASSWORD_PATH = os.getenv(
    "RADIO65_TEMP_CONTRIBUTOR_PASSWORD_PATH",
    "server/radio65-temp-contributor-password.txt",
)

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
