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

    // TODO: use mediaUrl once per-event stream URLs are supported - today
    // there's only ever one real stream, so this is hardcoded.
    readonly property string liveStreamUrl: "https://live.uuu.ee:4443/hls/stream.m3u8"

    property var liveInfo: null
    property bool loading: true
    property string errorMessage: ""

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
        audioOutput: AudioOutput {}
        videoOutput: videoOutput

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.BufferedMedia)
                root.loading = false;
        }

        onErrorOccurred: (error, errorString) => {
            root.loading = false;
            if (root.isLive && error === MediaPlayer.ResourceError)
                root.errorMessage = qsTr("No live stream");
            else
                root.errorMessage = errorString || qsTr("Playback failed");
        }
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
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.loading
        visible: running
    }

    Label {
        anchors.centerIn: parent
        anchors.margins: 16
        width: parent.width - 32
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        visible: root.errorMessage !== ""
        text: root.errorMessage
    }

    function startPlayback() {
        if (root.isLive) {
            refreshLiveInfo();
            player.source = root.liveStreamUrl;
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
