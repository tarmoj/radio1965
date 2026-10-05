"""
Plain SMTP email sending - currently only the "Become a Contributor"
confirmation link (project-description.md #10.2). Kept to stdlib
(smtplib/email) rather than a third-party transactional-email API, same
minimal-dependencies spirit as server/config.py's own header comment.
"""

import logging
import smtplib
import ssl
from email.message import EmailMessage

from server import config

logger = logging.getLogger(__name__)

# Port 465 is "implicit TLS" (the connection is encrypted from the first
# byte) - a different smtplib entry point (SMTP_SSL) than the more common
# port 587 "STARTTLS" (connect plain, then upgrade) - they are NOT
# interchangeable, mixing them up just fails to connect. mail.eccm.ee uses
# 465/implicit, hence this being keyed off the port rather than hardcoding
# one or the other.
_IMPLICIT_TLS_PORT = 465


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

    if config.SMTP_PORT == _IMPLICIT_TLS_PORT:
        smtp_cm = smtplib.SMTP_SSL(config.SMTP_HOST, config.SMTP_PORT, context=ssl.create_default_context())
    else:
        smtp_cm = smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT)

    with smtp_cm as smtp:
        if config.SMTP_PORT != _IMPLICIT_TLS_PORT:
            smtp.starttls(context=ssl.create_default_context())
        if config.SMTP_USER:
            smtp.login(config.SMTP_USER, config.SMTP_PASSWORD)
        smtp.send_message(message)

    logger.info("Sent email to '%s': %s", to, subject)
