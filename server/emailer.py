"""
Plain SMTP email sending - currently only the "Become a Contributor"
confirmation link (project-description.md #10.2). Kept to stdlib
(smtplib/email) rather than a third-party transactional-email API, same
minimal-dependencies spirit as server/config.py's own header comment.
"""

import logging
import smtplib
from email.message import EmailMessage

from server import config

logger = logging.getLogger(__name__)


def send_email(to: str, subject: str, body: str) -> None:
    """
    Best-effort: if config.SMTP_HOST isn't set (e.g. local/dev runs with no
    real mail server configured), logs a warning and returns instead of
    raising - same "don't hard-fail the caller" style as
    notifications.py's FCM sending. A real send that fails for some other
    reason (auth, connection) *does* raise, since that's the caller's only
    signal that the confirmation email didn't actually go out.
    """
    if not config.SMTP_HOST:
        logger.warning("SMTP_HOST not configured - not sending email to '%s': %s", to, subject)
        return

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = config.SMTP_FROM
    message["To"] = to
    message.set_content(body)

    with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT) as smtp:
        smtp.starttls()
        if config.SMTP_USER:
            smtp.login(config.SMTP_USER, config.SMTP_PASSWORD)
        smtp.send_message(message)

    logger.info("Sent email to '%s': %s", to, subject)
