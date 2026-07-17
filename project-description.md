# Radio 1965: unified event/media platform (Qt client + Linux server)

## 1. General description
        
      
The software  forwards different content (articles, audio/video, live streams, different web content) to users. It  consists of three parts:  

Event server (written in python) -  records events (new content created/edited/deleted ) in database (or JSON file) and forwards them via push notifications to  users apps.   Some content can be created in separate JOOMLA system, a bridge is neede to retriece the content of articles.

Client app  (Android, iOS, based on Qt platform) -  receives notifications on new content and shows relevant content. Enables search in past events/content.

Editor page (html/javascript/php) -  frontend for server management: for entering new events/creating content, .  

The server runs on Ubuntu 18.04, streaming service is already set up.

## 2. Notes for client app

  - For web content (articles, embedded conent) on iOS/Android: use `QtWebView` (wraps native WKWebView / Android WebView).
  - WebAssembly: Don't embed a
    web engine at all — use an `<iframe>` via JS interop for "webcontent"     posts, or native browser capability directly.
    
- Use `QtMultimedia` (with a capable backend, e.g. `libmpv` or GStreamer) to   play HLS/DASH/RTMP directly. 



## 3. Main architecture

```
Qt/QML client (iOS/Android (maybe WASM for demo)
        |
        v
   Events API  <---- Admin panel (native content entry: streams, live events)
        |
   Events DB   <---- Joomla importer (polls/receives webhook from Joomla,
        |             normalizes articles into the Events schema)
        v
 Notification service (FCM for Android/web push, APNs for iOS)
        
 Streaming server (Icecast/Liquidsoap for audio, RTMP->HLS via nginx-rtmp or MediaMTX for video) — Events DB just stores the resulting stream URL  and live/offline status.
```

Principles:
- The **Events API/DB is the single source of truth** the client talks to.
  It's a thin, purpose-built service — not a general CMS — so it can model
  streams, live status, and time windows cleanly.
- **Joomla stays as an editorial tool for article content only**, feeding   the Events DB through an importer, not queried live by the client. This   avoids coupling the app's uptime/performance to Joomla and avoids forcing   streaming/event concepts into Joomla's data model.
- **Streaming infrastructure is decoupled** from the CMS entirely; the  Events DB just references it.

## 4. Event JSON schema (draft, v1)

```json
{
  "id": "evt_2026_07_16_001",
  "type": "audiostream | videostream | article | webcontent",
  "title": "string",
  "summary": "string",
  "url": "https://...",
  "thumbnail_url": "https://...",
  "status": "upcoming | live | past",
  "starts_at": "2026-07-20T18:00:00Z",
  "ends_at": "2026-07-20T19:00:00Z",
  "source": "native | joomla_import",
  "source_ref": "joomla article id, if imported",
  "tags": ["string"],
  "payload": {},
  "comments_enabled": true
}
```

`payload` is type-specific extra data (e.g. stream bitrate/codec info, embedded webapp config). Keep the top level stable; put anything volatile or type-specific in `payload` so the schema doesn't need to change per content type.

## 5. Notification system

- Use  Firebase and FastAPI on server side for push notifications. See fcm_notify_example.py. 
- Client: FCM on Android and web (WASM), APNs on iOS. Use Firebase API (via wrapper classes).


## 6. Joomla import

- Needs work to clarify: maybe Joomla import is poll-based (cron) or event-based (a small  Joomla plugin fires a webhook on article publish/update).



