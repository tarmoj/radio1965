import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Window

// Pushed onto Main.qml's StackView (with the shared PlaybackController
// instance passed as an initial property) only while the currently-playing
// media - either a video file or, hypothetically, a video stream - actually
// has a video track. Popping this page (the back button) does not stop
// playback, it just stops rendering it.
//
// Windowed mode: playback is controlled by the always-visible PlayerBar
// strip above the StackView, same as before - the top bar here is just
// back/title/fullscreen-toggle, always visible, styled as an overlay
// (transparent background) purely so both modes share one structure.
//
// Fullscreen mode: Main.qml hides PlayerBar while
// Window.visibility===FullScreen (it has no room and would defeat the
// point of fullscreen), so this page grows its own auto-hiding overlay
// controls (top: back/title/exit-fullscreen, bottom: play/pause/seek/time)
// - tap the video to reveal, fades out after a few seconds of inactivity.
// project-description.md TODOs: "Video fullscreen dows not fill the screen
// on mobile devices" / "the seek bar should be below the video... how in
// fullscreen" - both addressed by VideoOutput now always filling the whole
// Page (no header reserving space) and this overlay pair.
Page {
    id: root
    required property PlaybackController controller

    readonly property bool fullscreenActive: root.Window.window && root.Window.window.visibility === Window.FullScreen
    property bool controlsVisible: true

    function toggleFullscreen() {
        if (!root.Window.window)
            return;
        root.Window.window.visibility = root.fullscreenActive ? Window.Windowed : Window.FullScreen;
        root.controlsVisible = true;
    }

    // Same small independent duplicate as PlayerBar.qml's formatTime()/
    // BroadcastPage.qml's formatElapsed() - established convention in this
    // codebase for this exact helper rather than a shared utility import.
    function formatTime(ms) {
        function pad(n) { return (n < 10 ? "0" : "") + n; }
        const totalSeconds = Math.max(0, Math.floor(ms / 1000));
        const m = Math.floor(totalSeconds / 60);
        const s = totalSeconds % 60;
        return pad(m) + ":" + pad(s);
    }

    background: Rectangle { color: "black" }

    Timer {
        id: hideControlsTimer
        interval: 3000
        running: root.fullscreenActive && root.controlsVisible
        onTriggered: root.controlsVisible = false
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent

        TapHandler {
            // Only meaningful in fullscreen - windowed mode's top bar is
            // always visible (see topBar.visible below), nothing to reveal.
            onTapped: if (root.fullscreenActive) root.controlsVisible = true
        }
    }

    Rectangle {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: topBarRow.implicitHeight + 12
        color: root.fullscreenActive ? "#99000000" : "transparent"
        visible: !root.fullscreenActive || root.controlsVisible

        RowLayout {
            id: topBarRow
            anchors.fill: parent
            anchors.margins: 6

            ToolButton {
                text: "←"
                onClicked: root.StackView.view.pop()
            }

            Label {
                text: root.controller.displayTitle
                color: root.fullscreenActive ? "white" : Material.foreground
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ToolButton {
                icon.source: root.fullscreenActive ? "qrc:/images/fullscreen_exit.svg" : "qrc:/images/fullscreen.svg"
                onClicked: root.toggleFullscreen()
            }
        }
    }

    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: bottomBarRow.implicitHeight + 12
        color: "#99000000"
        // Windowed mode still has PlayerBar for this - only shown here
        // once PlayerBar is hidden for fullscreen (see Main.qml).
        visible: root.fullscreenActive && root.controlsVisible

        RowLayout {
            id: bottomBarRow
            anchors.fill: parent
            anchors.margins: 8

            ToolButton {
                icon.source: root.controller.player.playbackState === MediaPlayer.PlayingState
                             ? "qrc:/images/pause.svg" : "qrc:/images/play.svg"
                onClicked: root.controller.togglePlayPause()
            }

            Label { color: "white"; text: root.formatTime(root.controller.player.position) }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: root.controller.player.duration
                value: root.controller.player.position
                onMoved: root.controller.player.position = value
            }

            Label { color: "white"; text: root.formatTime(root.controller.player.duration) }
        }
    }

    Component.onCompleted: root.controller.player.videoOutput = videoOutput
    Component.onDestruction: root.controller.player.videoOutput = null
}
