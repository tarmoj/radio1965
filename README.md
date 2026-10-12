# VÄIN

**VÄIN** (Estonian for "strait" — a narrow body of water with a depth
undetectable from the surface and a layered structure that constantly
varies) is an app developed for the **"Radio Tallinn 1965"** project, run
by the **Estonian Centre for Contemporary Music (ECCM)**. It's an
intermediate area that bridges one time to another, connecting not just
the past and the present, but also the people using it.

## What users can do

- **Listen** to the always-on `radio1965` channel, a live `live` broadcast,
  or one of several user channels, and watch the video stream.
- **Follow** a feed of new arrivals — articles, text messages, audio,
  video, and shared web content — with push notifications about new ones.
- **Browse the Collection** of everything shared so far, grouped by
  author, month, or title, with search.
- **Become a Contributor** to publish content or broadcast under your own
  name:
  - Register permanently (name, e-mail, password) or unlock a temporary
    contributor role with a shared password, from the app's menu.
  - Broadcast live audio straight from the app on one of the open
    channels (or on `live`, for managers).
  - **Share a Gem** — publish text, audio, video, or web content through
    a browser-based editor, already logged in.
  - Log in, reset a forgotten password, or delete your registration data
    again at any time, all from the same menu.

See [PRIVACY.md](PRIVACY.md) for what information is collected from
Contributors and how it's used.

## Repository layout

- `app/` — the Qt/QML client (desktop, Android, iOS).
- `server/` — the FastAPI notification/events server and its database
  schema helpers.
- `sql/` — the Events DB schema (MySQL/MariaDB).
- `editor/` — the browser-based "Share a gem" content editor.
- `contributor/` — the browser-based register/login/forgot-password page.
- `client/` — a minimal web test client for the server API.
- `project-description.md` — the project's running feature/design spec.
