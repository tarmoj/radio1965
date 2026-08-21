import QtQuick
import QtMultimedia

// Global playback state, replacing the per-page MediaPlayer that used to
// live inside PlayerPage.qml. Instantiated exactly once in Main.qml (id:
// playbackController) and passed down explicitly to PlayerBar, VideoPage,
// and EventListView - same "pass it down" convention this codebase already
// uses for navigationStack/serverBaseUrl - rather than as a `pragma
// Singleton`: bare `PlaybackController.xxx` global access did not resolve
// at runtime in this Qt/CMake setup (qmldir did not pick up the singleton
// registration from QML_FILES), so an explicitly-instantiated-and-threaded
// object is used instead. Not page-scoped, so playback survives tab
// switches and StackView pushes.
QtObject {
    id: root

    // Fallback for isLive when no per-event url is set - a tapped
    // livestream card with a real url (e.g. an Icecast channel, see
    // app/icecastbroadcaster.cpp) plays that instead, per start().
    readonly property string liveStreamUrl: "https://live.uuu.ee:4443/hls/stream.m3u8"

    // Fixed mount list, same as BroadcastPage.qml's channelNames, plus
    // "video" for the main HLS stream (liveStreamUrl).
    readonly property var channelOptions: ["radio1965", "user1", "user2", "user3", "user4", "video"]

    property string mediaUrl: ""
    property string mediaTitle: ""
    property string mediaSummary: ""
    // Defaults true (not false) so the channel picker in PlayerBar.qml is
    // visible immediately on launch - the "Live" tab that used to be the
    // discovery/entry point for tuning in is gone, so the persistent strip
    // has to take over that role. Nothing actually plays until the user
    // presses Play or picks a channel, though - see start()/selectChannel().
    property bool isLive: true
    property string selectedChannel: "radio1965"
    readonly property bool showChannelSelector: root.isLive && root.mediaUrl === ""

    property bool loading: false
    property string errorMessage: ""
    // Specifically "the live HLS/Icecast source 404s" (MediaPlayer.ResourceError
    // while isLive), as opposed to some other playback error - drives the
    // auto-retry Timer below without spamming retries for unrelated errors.
    property bool liveStreamOffline: false
    property bool expanded: false

    property var liveInfo: null
    readonly property string displayTitle: liveInfo ? liveInfo.title
                                                      : (root.mediaTitle || (root.isLive ? qsTr("Live Stream") : ""))
    readonly property string displaySummary: liveInfo ? liveInfo.summary : root.mediaSummary

    function refreshLiveInfo() {
        if (!root.isLive) {
            // Otherwise a stale liveInfo from a previous live session would
            // keep overriding displayTitle/displaySummary for whatever
            // plays next (e.g. switching to a video event) - see start(),
            // which now calls this unconditionally instead of only when
            // isLive.
            root.liveInfo = null;
            return;
        }
        const info = notificationManager.findLiveStream();
        root.liveInfo = (info && info.title) ? info : null;
    }

    property Connections _notificationConnections: Connections {
        target: notificationManager
        function onDataChanged() { root.refreshLiveInfo(); }
        function onRowsInserted() { root.refreshLiveInfo(); }
        function onRowsRemoved() { root.refreshLiveInfo(); }
    }

    function channelUrl(channel) {
        return channel === "video" ? root.liveStreamUrl : ("http://live.uuu.ee:8001/" + channel);
    }

    // Called by PlayerBar's channel ComboBox: switches immediately if
    // something is already playing/loading, otherwise just records the
    // choice - avoids firing network requests on every combobox change
    // while idle (the default state on launch).
    function selectChannel(channel) {
        root.selectedChannel = channel;
        root.isLive = true;
        root.mediaUrl = "";
        root.mediaTitle = "";
        root.mediaSummary = "";
        if (root.loading || player.playbackState !== MediaPlayer.StoppedState) {
            root.start();
        } else {
            // Otherwise player.source still holds whatever channel/file was
            // loaded before - togglePlayPause()'s "nothing loaded yet"
            // check (player.source === "") would miss that a *different*
            // channel was picked, and a subsequent Play press would just
            // resume the old source instead of loading the new one.
            player.source = "";
        }
    }

    // Called by EventListView.qml instead of pushing PlayerPage.qml.
    function playMedia(url, title, summary, isLive) {
        root.isLive = isLive;
        root.mediaUrl = url;
        root.mediaTitle = title;
        root.mediaSummary = summary;
        root.start();
    }

    function start() {
        root.loading = true;
        root.errorMessage = "";
        root.liveStreamOffline = false;

        // Reassigning `source` to the same URL it already holds is a no-op
        // in QML (the write is skipped when the new value equals the
        // cached one) - clearing it first forces MediaPlayer to genuinely
        // reload instead of silently doing nothing.
        player.source = "";
        root.refreshLiveInfo();
        if (root.isLive) {
            player.source = root.mediaUrl || root.channelUrl(root.selectedChannel);
        } else {
            player.source = root.mediaUrl;
        }
        player.play();
    }

    function togglePlayPause() {
        // player.source is QUrl-typed, not a plain string - comparing it
        // to "" with === (or even ==) never matches even when the URL is
        // genuinely empty (e.g. on fresh launch, before anything has ever
        // been loaded), because QML exposes it as a "url" value-type
        // object rather than a JS string. .toString() forces a real
        // comparison. Without this fix, pressing Play on first launch fell
        // through to player.play() with nothing loaded - a silent no-op.
        if (player.source.toString() === "" && !root.loading) {
            root.start();
        } else if (player.playbackState === MediaPlayer.PlayingState) {
            player.pause();
        } else {
            player.play();
        }
    }

    // Just stops playback - does NOT touch mediaUrl/isLive/title, so the
    // strip keeps showing what was loaded (e.g. an audio file's title, with
    // Play available to resume it) instead of jumping back to the channel
    // picker on its own. Previously this reset straight to radio mode,
    // which looked wrong when Stop was pressed on a fixed-media item (the
    // combobox would appear even though the file was still the loaded
    // item) - use backToChannels() for an explicit return to radio mode.
    function stop() {
        player.stop();
        root.errorMessage = "";
        root.liveStreamOffline = false;
    }

    // Explicit "done listening to this file, back to radio" action - called
    // from PlayerBar when the user taps the media-type icon while on fixed
    // media (see showChannelSelector).
    function backToChannels() {
        player.stop();
        player.source = "";
        root.mediaUrl = "";
        root.mediaTitle = "";
        root.mediaSummary = "";
        root.liveInfo = null;
        root.isLive = true;
        root.errorMessage = "";
        root.liveStreamOffline = false;
    }

    property MediaPlayer player: MediaPlayer {
        id: player
        audioOutput: AudioOutput {}

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.BufferedMedia)
                root.loading = false;
        }

        onErrorOccurred: (error, errorString) => {
            root.loading = false;
            if (root.isLive && error === MediaPlayer.ResourceError) {
                root.liveStreamOffline = true;
                root.errorMessage = qsTr("No live stream");
            } else {
                root.liveStreamOffline = false;
                root.errorMessage = errorString || qsTr("Playback failed");
            }
        }
    }

    // Drives auto-retry: a live source can go from offline to on-air while
    // the user is elsewhere in the app, and MediaPlayer never retries a
    // failed source on its own. Global now (no SwipeView-visibility gating
    // needed like the old embedded Live tab had) since this is always
    // relevant regardless of which page is currently showing.
    property Timer _retryTimer: Timer {
        interval: 8000
        repeat: true
        running: root.isLive && root.liveStreamOffline
        onTriggered: root.start()
    }
}
