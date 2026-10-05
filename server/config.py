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
    "server/config/radio65-temp-contributor-password.txt",
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

# SMTP settings for the "Become a Contributor" confirmation email
# (project-description.md #10.2) - see server/emailer.py. Host/port/user/
# from aren't secret, so (like FIREBASE_CRED_PATH/
# TEMPORARY_CONTRIBUTOR_PASSWORD_PATH above) they get a real default here,
# still overridable via env var if that ever changes. Only SMTP_PASSWORD is
# a secret - that one has no default, set it via server/set_env.sh
# (gitignored), same as RADIO65_DATABASE_URL above.
#
# mail.eccm.ee, port 465 = implicit TLS, not STARTTLS - see
# emailer.py's send_email(), which branches on the port to pick the right
# one. An empty SMTP_HOST is still a valid, supported state
# (emailer.send_email() logs a warning and no-ops instead of raising) so
# local/dev runs without a real mail server don't hard-fail registration.
SMTP_HOST = os.getenv("RADIO65_SMTP_HOST", "mail.eccm.ee")
SMTP_PORT = int(os.getenv("RADIO65_SMTP_PORT", "465"))
SMTP_USER = os.getenv("RADIO65_SMTP_USER", "info@eccm.ee")
SMTP_PASSWORD = os.getenv("RADIO65_SMTP_PASSWORD", "")
SMTP_FROM = os.getenv("RADIO65_SMTP_FROM", "info@eccm.ee")

# This server's own public base URL (no trailing slash) - used to build the
# confirmation link embedded in that email, e.g.
# "https://live.uuu.ee/radio1965/api". Matches app/Main.qml's
# appSettings.serverUrl default.
PUBLIC_BASE_URL = os.getenv("RADIO65_PUBLIC_BASE_URL", "https://live.uuu.ee/radio1965/api")
