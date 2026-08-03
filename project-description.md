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

### 2.1 Client app UI and functinality

The overall logic is similar to a library (of books) - there is counter of new itmes (New Arrivals), shelves (Collection) and Archive where materials to be out of site can be still be accessible.
An entry is called an "item" instead of "event"  now.

On startup or a push notification arriving, the app pulls data via notification server API, updates its internal data and shows the content.
The main internal data is a model that refers to  events table in the database, where status is "new" or "shelved". If status is "archived", the items are shown only when searched for, "unpublished" are never shown.
On exit the app stores the models state in app settings.

// note for myaself: Kartoteek (Estonian) = Card Catalog; Kaart = Entry or Card.

Visually the main element is a Card with  a title, summary, type, maybe later also category, (later also thumbnail) on it. 
Use separate QML component Card.qml for it. Set necessary proeprties. 
For now use something like the listviews delegate for it:

Rectangle {
                        width: messageListView.width
                        height: messageColumn.implicitHeight + 20
                        radius: 5
                        color: Material.backgroundColor.lighter()
                        border.width: 1
                        border.color: // Card.color

                        ColumnLayout {
                            id: messageColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            Label {
                                text: title
                                font.bold: true
                                font.pointSize: 13
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: summary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            // other necessary fields

                            Mousearea { ... }
                        }

Use different border colors for different types.

When user clicks on the card, the contents are retrieved and shown in a content component (probably via WebView). Always show also the title on the component. Add Close, Next, Previous button.

Behaviour by types:
- text -  just show the plain text
- article -  pull content from joomla API (see joomla_importer.py) and show it as html.
- audio, video, streams -  to be implemented
- web content -  use iframe and show given content.

The app has three main pages/views:
- New Arrivals 
- Collection (Shelves)
-- for now organized by type (text, article, audio etc), later by categories
- Archive
-- Search form, do not implent now.

Use TabBar + SwipeView for it:
Something like:
```
ApplicationWindow {
    footer: TabBar {
        id: tabBar
        TabButton { text: "New Arrivals" }
        TabButton { text: "Collection" }
        TabButton { text: "Archive" }
    }

    SwipeView {
        anchors.fill: parent
        currentIndex: tabBar.currentIndex
        NewArrivalsPage {}
        CollectionPage {}
        ArchivePage {}
    }
}
```
For Content use StackView, that covers the main content area (between header and above footer)


Later use a slim, persistent mini-player bar that survives across tab switches and stack pushes/pops (sitting between the SwipeView and the TabBar, or docked just above it

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

## 4. Event JSON schema (draft, v2)


Type: 
text - simple text message (can be rich text), no media
audio| video -  link to url
audiostream | videostream -  live
article - html content from joomla or possible elsewhere
webcontent - iframe to anything

Skip thumbnail (url) for now, later perhaps automatic on  UI.
"comments_enabled": true  - for later
"status": "upcoming | live | past", -  probably not necessary

"payload" -  any data necessary to send

"shelf_at" - before that the message us shown in "CURRENT" or "NEW" in UI, later moves to "shelf"

```json
{
  "id": "evt_2026_07_16_001",
  "type": "text | audio | video | audiostream | videostream | article | webcontent",
  "title": "string",
  "summary": "string",
  "url": "https://...",
  "publish_at": "2026-07-20T18:00:00Z",
  "shelf_at": "2026-07-20T19:00:00Z",
  "status": "unpublished | new | shelved | archived", 
  "tags": ["string"],
  "payload": {},
 
}
```

`payload` is type-specific extra data (e.g. stream bitrate/codec info, embedded webapp config). Keep the top level stable; put anything volatile or type-specific in `payload` so the schema doesn't need to change per content type.

## 5. Notification system

- Use  Firebase and FastAPI on server side for push notifications. See fcm_notify_example.py. 
- Client: FCM on Android and web (WASM), APNs on iOS. Use Firebase API (via wrapper classes).
- Use cron system (every minute) to check if new events must be sent or some event changes status (new->shelved)


## 6. Joomla import

- Needs work to clarify: maybe Joomla import is poll-based (cron) or event-based (a small  Joomla plugin fires a webhook on article publish/update).

Process:
- user creates the article with joomla content creator in given category (47 at the moment); 
- remote server (that runs also notification server and database) checks via a crontab job if there are new articles 
-- Joomla API address:  https://eccm.ee/api/index.php/v1
-- get JOOMLA_API_KEY from enviroment
-- initial filters: content/articles?filter[state]=1&filter[category]=47 
- if there are new articles, adds them to notification database, using the publish_up for notification publish time (use 'now', if the time is in past) and publish_down ad "move to shelf" time in the database. If is unset, take 7 days from publish time,  



## 7. Editor

Web page that manages events in the database. Notification server uses cron to send new events.
Also accept "Now" as possible publish time (send directily to notification server and set published_at to current time).

Common fields to all types:
- Title 
- Summary (used in notification text):
- Type: "text | audio | video | audiostream | videostream | article | webcontent"
- Announce at:  time/date select,  support also "Now" 
- Put to shelf at (moved from "new" items to normal, "shelved" items) // optional, if empty, take a week from publishing time
- Tags (comma separated)

The 'status' is set to 'unpublished' by default, unless publish is "now"
Use smart seach for Tags (when user start to type, suggest existing tags. If it is s new tag, add it to the database, table tags)

Other parameters that do not have a db field are kept/sent in payload field.

Fields depending on type:
"text": 
- Text 
- no URL

All others:
- Content URL:

"audiostream | videostream":
- Live at  // time, send in payload
- Server address: // default https://live.uuu.ee/stream

TODO: proper support of audio streams, needs a separate streaming service.


## 99. Ideas.

Think of the app/project as **library** -  new items, catlogues, shelves, items lost, order/wish lists, meeting with authors, *vorlesungen* etc I
