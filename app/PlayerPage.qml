import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// Renders "audio"/"video"/"audiostream"/"videostream" events
// (project-description.md #2, #4). Live types just hide the seek bar -
// full HLS/RTMP robustness is deferred (see app/CMakeLists.txt comment
// on qt_add_ios_ffmpeg_libraries).
Page {
    id: root

    required property string mediaUrl
    property string mediaTitle: ""
    property bool isLive: false

    header: ToolBar {
        RowLayout {
            anchors.fill: parent

            ToolButton {
                text: "←"
                onClicked: {
                    player.stop();
                    root.StackView.view.pop();
                }
            }

            Label {
                text: root.mediaTitle
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
        source: root.mediaUrl
        audioOutput: AudioOutput {}
        videoOutput: videoOutput
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        VideoOutput {
            id: videoOutput
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: player.hasVideo
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

    Component.onCompleted: player.play()
    Component.onDestruction: player.stop()
}
