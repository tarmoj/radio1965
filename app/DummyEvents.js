.pragma library

// Seeds notificationManager.upsertEvents() instead of a real
// eventsApiClient.fetchEvents() call - see Main.qml's layoutPreview
// branch and app/CMakeLists.txt's RADIO65_LAYOUT_PREVIEW option. Fields
// match server/db.py's Event.to_dict() (not the stale shape the
// abandoned `design` branch's Form-default dummy arrays used, which
// predates author_name).
var events = [
    {
        id: "evt_dummy_1",
        type: "audio",
        title: "Interview with a sound artist",
        summary: "A conversation about field recording and tape loops.",
        url: "https://example.com/sample.mp3",
        publish_at: "2026-10-10T09:00:00",
        shelf_at: "2026-10-11T09:00:00",
        status: "new",
        comments_enabled: true,
        tags: ["interview", "sound-art"],
        payload: {},
        author_id: 1,
        author_name: "Tarmo Johannes"
    },
    {
        id: "evt_dummy_2",
        type: "video",
        title: "Behind the scenes",
        summary: "A short video tour of the studio setup.",
        url: "https://example.com/sample.mp4",
        publish_at: "2026-09-02T14:00:00",
        shelf_at: "2026-09-03T14:00:00",
        status: "shelved",
        comments_enabled: false,
        tags: ["studio"],
        payload: {},
        author_id: 2,
        author_name: "Jane Doe"
    },
    {
        id: "evt_dummy_3",
        type: "webcontent",
        title: "A page worth visiting",
        summary: "An external page shared without a known author.",
        url: "https://example.com",
        publish_at: "2026-08-15T12:00:00",
        shelf_at: "2026-08-16T12:00:00",
        status: "shelved",
        comments_enabled: false,
        tags: [],
        payload: {},
        author_id: null,
        author_name: null
    },
    {
        id: "evt_dummy_4",
        type: "text",
        title: "A short message",
        summary: "Just a quick note shared with everyone.",
        url: "",
        publish_at: "2026-10-05T08:30:00",
        shelf_at: "2026-10-06T08:30:00",
        status: "shelved",
        comments_enabled: true,
        tags: ["note"],
        payload: { text: "This is the full message body, only shown once the card is expanded." },
        author_id: 1,
        author_name: "Tarmo Johannes"
    },
    {
        id: "evt_dummy_5",
        type: "streamrecording",
        title: "Saved broadcast recording",
        summary: "A recording of a finished live broadcast.",
        url: "https://example.com/recording.mp3",
        publish_at: "2026-10-08T20:00:00",
        shelf_at: "2026-10-09T20:00:00",
        status: "shelved",
        comments_enabled: false,
        tags: ["broadcast"],
        payload: {},
        author_id: 2,
        author_name: "Jane Doe"
    }
]
