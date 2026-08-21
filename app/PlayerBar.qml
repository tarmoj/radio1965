import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// Persistent, always-visible mini-player strip - lives above the StackView
// in Main.qml (not inside a tab/page) so it survives tab switches and
// pushed pages (WebViewPage, VideoPage). All actual playback state lives in
// the PlaybackController instance passed in from Main.qml; this is purely
// the view.
Item {
    id: root
    required property PlaybackController controller
    implicitHeight: contentColumn.implicitHeight + 12

    function formatTime(ms) {
        // Same duration-formatting approach as BroadcastPage.qml's
        // formatElapsed() - not Qt.formatTime(new Date(ms)), which renders
        // in local time and is wrong by the timezone offset at ms=0.
        function pad(n) { return (n < 10 ? "0" : "") + n; }
        const totalSeconds = Math.max(0, Math.floor(ms / 1000));
        const m = Math.floor(totalSeconds / 60);
        const s = totalSeconds % 60;
        return pad(m) + ":" + pad(s);
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 6

        RowLayout {
            id: controlsRow
            //Layout.alignment: Qt.AlignHCenter
            spacing: 2

            BusyIndicator {
                implicitWidth: 20
                implicitHeight: 20
                running: root.controller.loading
                visible: running
            }

            Image {
                source: root.controller.isLive ? "qrc:/images/radio.svg" :
                            "qrc:/images/audio_file.svg"
                //visible: root.controller.showChannelSelector
                sourceSize.width: 18
                sourceSize.height: 18
            }



            ComboBox {
                id: channelCombo
                Layout.preferredWidth: 110
                visible: root.controller.showChannelSelector
                model: root.controller.channelOptions
                currentIndex: root.controller.channelOptions.indexOf(root.controller.selectedChannel)
                onActivated: root.controller.selectChannel(root.controller.channelOptions[currentIndex])
                background: Rectangle {
                    implicitWidth: 110
                    implicitHeight: 32
                    radius: 4
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"
                }
            }

            // Fixed media (an event's own url, not the live channel picker)
            // takes the channel combobox's spot in the compact row instead
            // of only showing in the expanded section - visible whenever
            // the combobox isn't.
            Label {
                Layout.preferredWidth: 110
                elide: Text.ElideRight
                visible: !root.controller.showChannelSelector
                text: root.controller.displayTitle
            }

            Image {
                source: "qrc:/images/sound.svg"
                // sourceSize.width: 18
                // sourceSize.height: 18
            }

            Slider {
                Layout.preferredWidth: 80
                Layout.minimumWidth: 30
                Layout.fillWidth:  true
                from: 0
                to: 1
                value: root.controller.player.audioOutput.volume
                onMoved: root.controller.player.audioOutput.volume = value
            }

            ToolButton {
                icon.source: root.controller.player.playbackState === MediaPlayer.PlayingState
                             ? "qrc:/images/pause.svg" : "qrc:/images/play.svg"
                onClicked: root.controller.togglePlayPause()
            }

            ToolButton {
                icon.source: "qrc:/images/stop.svg"
                onClicked: root.controller.stop()
            }

            ToolButton {
                icon.source: root.controller.expanded ? "qrc:/images/arrow_drop_up.svg" :
                                                        "qrc:/images/arrow_drop_down.svg"
                //text: root.controller.expanded ? "▴" : "▾"
                onClicked: root.controller.expanded = !root.controller.expanded
            }
        }

        RowLayout {

            Layout.fillWidth: true
            spacing: 4
            visible: root.controller.expanded

            Item { Layout.preferredWidth: 12} // spacer

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: root.controller.displaySummary.length > 0
                text: root.controller.displaySummary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !root.controller.isLive

                Label { text: root.formatTime(root.controller.player.position) }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: root.controller.player.duration
                    value: root.controller.player.position
                    onMoved: root.controller.player.position = value
                }

                Label { text: root.formatTime(root.controller.player.duration) }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Reload")
                visible: root.controller.errorMessage !== ""
                onClicked: root.controller.start()
            }
        }
    }

    // Errors need to be visible even when the strip is collapsed (the
    // expanded section's Reload button alone isn't enough - a plain
    // Rectangle here would get painted over by the StackView sibling below
    // PlayerBar in Main.qml, since ordinary z only reorders siblings under
    // the same parent). A Popup renders through the window's overlay layer
    // instead, so it stays on top regardless of expand/collapse state.
    Popup {
        x: (root.width - width) / 2
        y: contentColumn.height + 4
        visible: root.controller.errorMessage !== ""
        modal: false
        focus: false
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        background: Rectangle {
            color: "crimson"
            radius: 4
        }
        contentItem: Label {
            padding: 6
            color: "white"
            text: root.controller.errorMessage
        }
    }
}
