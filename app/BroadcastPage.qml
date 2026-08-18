import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Lets the user go live on one of Icecast's 5 fixed mountpoints
// (project-description.md #8.1/#9), broadcasting microphone audio via
// IcecastBroadcaster (app/icecastbroadcaster.h/.cpp). Desktop-only: that
// C++ object is only registered as context property "icecastBroadcaster"
// when app/CMakeLists.txt's RADIO65_ENABLE_BROADCAST is defined, so this
// page checks for its existence at runtime rather than relying on a
// separate platform flag - keeps the tab itself always present (needed to
// keep TabBar/SwipeView index alignment, same convention used for "Live").
Page {
    id: root

    readonly property bool broadcastAvailable: typeof icecastBroadcaster !== "undefined"
    readonly property var channelNames: ["radio1965", "user1", "user2", "user3", "user4"]
    property var occupiedChannels: []

    function isChannelOccupied(channel) {
        return root.occupiedChannels.indexOf(channel) !== -1;
    }

    function formatElapsed(seconds) {
        return Qt.formatTime(new Date(seconds * 1000), "hh:mm:ss");
    }

    Connections {
        target: root.broadcastAvailable ? icecastBroadcaster : null
        function onOccupiedChannelsChanged(list) { root.occupiedChannels = list; }
        function onBroadcastError(message) { errorLabel.text = message; }
    }

    Component.onCompleted: {
        if (root.broadcastAvailable)
            icecastBroadcaster.refreshOccupiedChannels();
    }

    Label {
        anchors.centerIn: parent
        anchors.margins: 16
        width: parent.width - 32
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        visible: !root.broadcastAvailable
        text: qsTr("Broadcasting is only available on desktop for now.")
    }

    // Loader, not a plain Item with visible:false: this subtree's bindings
    // reference the "icecastBroadcaster" context property directly, which
    // doesn't exist at all on builds without RADIO65_ENABLE_BROADCAST -
    // visible:false alone wouldn't stop those bindings from being evaluated
    // (same ReferenceError class this session already hit once with
    // ListView's `model`), but an inactive Loader never instantiates its
    // content, so the bindings are simply never created.
    Loader {
        anchors.fill: parent
        anchors.margins: 16
        active: root.broadcastAvailable
        sourceComponent: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ComboBox {
                    id: channelCombo
                    Layout.fillWidth: true
                    enabled: !icecastBroadcaster.broadcasting
                    model: root.channelNames
                    delegate: ItemDelegate {
                        width: channelCombo.width
                        text: modelData
                        enabled: !root.isChannelOccupied(modelData)
                    }
                }

                ToolButton {
                    text: "⟳"
                    onClicked: icecastBroadcaster.refreshOccupiedChannels()
                }
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Name")
                enabled: !icecastBroadcaster.broadcasting
            }

            TextField {
                id: descriptionField
                Layout.fillWidth: true
                placeholderText: qsTr("Description")
                enabled: !icecastBroadcaster.broadcasting
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: icecastBroadcaster.broadcasting ? qsTr("Stop") : qsTr("Start")
                onClicked: {
                    if (icecastBroadcaster.broadcasting)
                        icecastBroadcaster.stopBroadcast();
                    else
                        icecastBroadcaster.startBroadcast(channelCombo.currentText, nameField.text, descriptionField.text);
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: icecastBroadcaster.onAir
                text: qsTr("● On air")
                color: "crimson"
                font.bold: true
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: icecastBroadcaster.broadcasting
                text: root.formatElapsed(icecastBroadcaster.elapsedSeconds)
            }

            Label {
                id: errorLabel
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: "crimson"
                visible: text !== ""
            }

            Item { Layout.fillHeight: true }
        }
    }
}
