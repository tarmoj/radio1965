import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Window

// Pushed onto Main.qml's StackView (with the shared PlaybackController
// instance passed as an initial property) only while the currently-playing
// media - either a video file or, hypothetically, a video stream - actually
// has a video track. Playback itself is controlled by the always-visible
// PlayerBar strip above the StackView, not by anything here - popping this
// page (the back button) does not stop playback, it just stops rendering
// it.
Page {
    id: root
    required property PlaybackController controller

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.margins: 5

            ToolButton {
                text: "←"
                onClicked: root.StackView.view.pop()
            }

            Label {
                text: root.controller.displayTitle
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ToolButton {
                icon.source: root.Window.window && root.Window.window.visibility === Window.FullScreen
                             ? "qrc:/images/fullscreen_exit.svg" : "qrc:/images/fullscreen.svg"
                onClicked: {
                    if (!root.Window.window)
                        return;
                    root.Window.window.visibility = (root.Window.window.visibility === Window.FullScreen)
                                                     ? Window.Windowed : Window.FullScreen;
                }
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
    }

    Component.onCompleted: root.controller.player.videoOutput = videoOutput
    Component.onDestruction: root.controller.player.videoOutput = null
}
