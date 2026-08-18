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
    property string errorMessage: ""

    function isChannelOccupied(channel) {
        return root.occupiedChannels.indexOf(channel) !== -1;
    }

    function formatElapsed(seconds) {
        // Not Qt.formatTime(new Date(seconds*1000), ...): that Date is
        // epoch-relative (UTC), and formatTime renders it in local time, so
        // e.g. Estonia's UTC+3 summer offset would always show "03:00:00"
        // at seconds=0. Format the duration directly instead.
        function pad(n) { return (n < 10 ? "0" : "") + n; }
        const total = Math.max(0, Math.floor(seconds));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return pad(h) + ":" + pad(m) + ":" + pad(s);
    }

    Connections {
        target: root.broadcastAvailable ? icecastBroadcaster : null
        function onOccupiedChannelsChanged(list) { root.occupiedChannels = list; }
        // root.errorMessage, not a Loader-internal id: ids declared inside
        // the Loader's inline sourceComponent below live in that Component's
        // own scope and aren't reachable from this outer Connections (that
        // was the "errorLabel is not defined" crash - e.g. when Icecast
        // rejects a connect attempt to an already-occupied channel).
        function onBroadcastError(message) { root.errorMessage = message; }
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
                    if (icecastBroadcaster.broadcasting) {
                        icecastBroadcaster.stopBroadcast();
                    } else {
                        root.errorMessage = "";
                        icecastBroadcaster.startBroadcast(channelCombo.currentText, nameField.text, descriptionField.text);
                    }
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
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: "crimson"
                text: root.errorMessage
                visible: text !== ""
            }

            Item { Layout.fillHeight: true }
        }
    }
}
