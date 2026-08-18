import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// Renders "audio"/"video"/"livestream" events (project-description.md #2,
// #4, #8). Live types just hide the seek bar - full HLS/RTMP robustness is
// deferred (see app/CMakeLists.txt comment on qt_add_ios_ffmpeg_libraries).
//
// Live streams: the HLS URL is hardcoded (project-description.md #8 - only
// one stream exists today) rather than taken from mediaUrl. Whether the
// stream is actually on air is decided by the player itself (a dead .m3u8
// surfaces as MediaPlayer.ResourceError), never by checking the events
// list - notificationManager.findLiveStream() is used purely to label the
// stream (Title/Description), not to gate playback.
//
// Used two ways: pushed onto the StackView when a card is tapped (has a
// back button, autoplays immediately - StackView.view is non-null then),
// and embedded directly as the "Live" SwipeView tab in Main.qml (no back
// button; SwipeView creates all its tabs eagerly at startup, so playback
// there is gated on SwipeView.isCurrentItem instead of Component.onCompleted,
// otherwise the stream would start playing the moment the app launches).
Page {
    id: root

    property string mediaUrl: ""
    property string mediaTitle: ""
    property string mediaSummary: ""
    property bool isLive: false

    // Fallback for isLive when no per-event url is set (the always-embedded
    // "Live" SwipeView tab in Main.qml, which passes no mediaUrl) - a
    // tapped livestream card with a real url (e.g. an Icecast channel, see
    // app/icecastbroadcaster.cpp) plays that instead, per startPlayback().
    readonly property string liveStreamUrl: "https://live.uuu.ee:4443/hls/stream.m3u8"

    property var liveInfo: null
    property bool loading: true
    property string errorMessage: ""
    // Specifically "the live HLS manifest 404s" (MediaPlayer.ResourceError
    // while isLive), as opposed to some other playback error - drives the
    // auto-retry Timer below without spamming retries for unrelated errors.
    property bool liveStreamOffline: false

    readonly property string displayTitle: liveInfo ? liveInfo.title
                                                      : (root.mediaTitle || (root.isLive ? qsTr("Live Stream") : ""))
    readonly property string displaySummary: liveInfo ? liveInfo.summary : root.mediaSummary

    function refreshLiveInfo() {
        if (!root.isLive)
            return;
        const info = notificationManager.findLiveStream();
        root.liveInfo = (info && info.title) ? info : null;
    }

    Connections {
        target: notificationManager
        function onDataChanged() { root.refreshLiveInfo(); }
        function onRowsInserted() { root.refreshLiveInfo(); }
        function onRowsRemoved() { root.refreshLiveInfo(); }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.margins: 5

            ToolButton {
                text: "←"
                visible: root.StackView.view !== null
                onClicked: {
                    player.stop();
                    root.StackView.view.pop();
                }
            }

            Label {
                text: root.displayTitle
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ToolButton {
                text: qsTr("Reload")
                onClicked: root.startPlayback()
            }

            Label {
                visible: root.isLive
                text: qsTr("LIVE")
                color: "crimson"
                font.bold: true
            }
        }
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput { id: audioOutput }
        videoOutput: videoOutput

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

    // Drives auto-retry: the stream can go from offline to on-air while the
    // user is sitting on the Live tab, and MediaPlayer never retries a
    // failed source on its own. Scoped tightly (live + currently known
    // offline + this page actually visible) so it doesn't spam retries for
    // an unrelated playback error or while the tab is swiped away.
    Timer {
        interval: 8000
        repeat: true
        running: root.isLive && root.liveStreamOffline
                 && (root.SwipeView.view === null || root.SwipeView.isCurrentItem)
        onTriggered: root.startPlayback()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        visible: !root.loading && root.errorMessage === ""

        VideoOutput {
            id: videoOutput
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: player.hasVideo
        }

        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !player.hasVideo
            text: qsTr("Audio only")
            font.pointSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Label {
            Layout.fillWidth: true
            visible: root.displaySummary.length > 0
            text: root.displaySummary
            wrapMode: Text.Wrap
        }

        Slider {
            Layout.fillWidth: true
            visible: !root.isLive
            from: 0
            to: player.duration
            value: player.position
            onMoved: player.position = value
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            ToolButton {
                icon.source: player.playbackState === MediaPlayer.PlayingState
                             ? "qrc:/images/pause.svg" : "qrc:/images/play.svg"
                onClicked: {
                    if (player.playbackState === MediaPlayer.PlayingState)
                        player.pause();
                    else
                        player.play();
                }
            }

            ToolButton {
                icon.source: "qrc:/images/stop.svg"
                onClicked: player.stop()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Image {
                source: "qrc:/images/sound.svg"
                sourceSize.width: 16
                sourceSize.height: 16
            }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: audioOutput.volume
                onMoved: audioOutput.volume = value
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.loading
        visible: running
    }

    Column {
        anchors.centerIn: parent
        anchors.margins: 16
        width: parent.width - 32
        spacing: 12
        visible: root.errorMessage !== ""

        Label {
            width: parent.width
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: root.errorMessage
        }
    }

    function startPlayback() {
        root.loading = true;
        root.errorMessage = "";
        root.liveStreamOffline = false;

        // Reassigning `source` to the same URL it already holds is a no-op
        // in QML (the write is skipped when the new value equals the
        // cached one) - clearing it first forces MediaPlayer to genuinely
        // reload instead of silently doing nothing, which is what made both
        // "stream starts while the tab stays open" and "revisit the tab"
        // fail to ever retry.
        player.source = "";
        if (root.isLive) {
            refreshLiveInfo();
            player.source = root.mediaUrl || root.liveStreamUrl;
        } else {
            player.source = root.mediaUrl;
        }
        player.play();
    }

    // Only relevant when embedded as a SwipeView tab (SwipeView.view is
    // null otherwise, and isCurrentItemChanged simply never fires) -
    // starts/pauses playback as the user swipes to/away from the Live tab.
    Connections {
        target: root.SwipeView
        function onIsCurrentItemChanged() {
            if (root.SwipeView.isCurrentItem)
                root.startPlayback();
            else
                player.pause();
        }
    }

    Component.onCompleted: {
        // If embedded in a SwipeView but not the tab shown at launch, wait
        // for onIsCurrentItemChanged above instead of streaming immediately.
        if (root.SwipeView.view === null || root.SwipeView.isCurrentItem)
            startPlayback();
    }

    Component.onDestruction: player.stop()
}
