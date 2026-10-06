import QtCore
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
Item {
    id: root

    readonly property bool broadcastAvailable: typeof icecastBroadcaster !== "undefined"
    // Passed in from Main.qml (userSettings.role === "contributor" or
    // "temporaryContributor") - gates the broadcast UI the same way
    // broadcastAvailable does, without removing the tab itself (see the
    // class comment above).
    property bool isContributor: false
    // Passed in from Main.qml (userSettings.role === "temporaryContributor")
    // - project-description.md #10.1's per-session broadcast time limit +
    // cooldown only apply to this role, never to a full "contributor".
    property bool isTemporaryContributor: false
    // Passed in from Main.qml (userSettings.accessToken) - forwarded into
    // IcecastBroadcaster.startBroadcast() so the published event's
    // author_id can be set server-side (see icecast_on_connect.sh).
    property string accessToken: ""
    // Passed in from Main.qml (userSettings.role === "manager") - gates
    // "live" below. project-description.md's Channels section: "live -
    // live audio broadcast (by managers)". Icecast itself also protects
    // /live with its own mount-specific password (see
    // icecastbroadcaster.cpp's ICECAST_LIVE_PASSWORD) - this UI gate alone
    // isn't the real enforcement, just keeps non-managers from seeing an
    // option that would fail to connect anyway.
    property bool isManager: false
    // "like 5 minutes" per project-description.md #10.1.
    readonly property int temporaryBroadcastLimitSeconds: 180 // 3 minutes
    // radio1965 (the always-on main channel) is deliberately excluded -
    // broadcast to it only by external tools (ezstream/raw ffmpeg directly
    // against Icecast, see icecastbroadcaster.cpp's own comments), never
    // picked here by an app user.
    readonly property var channelNames: root.isManager
        ? ["live", "user1", "user2", "user3", "user4"]
        : ["user1", "user2", "user3", "user4"]
    property var occupiedChannels: []
    property string errorMessage: ""

    //background: Rectangle { color: "transparent" }

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
        visible: !root.broadcastAvailable || !root.isContributor
        text: !root.broadcastAvailable
              ? qsTr("Broadcasting is only available on desktop for now.")
              : qsTr("Become a Contributor from the menu to unlock broadcasting.")
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
        active: root.broadcastAvailable && root.isContributor
        sourceComponent: ColumnLayout {
            spacing: 12

            // Persisted across app restarts, same QtCore Settings pattern as
            // Main.qml's appSettings - remembers the last-used name,
            // description and channel so the user doesn't retype them every
            // broadcast.
            Settings {
                id: broadcastSettings
                category: "Broadcast"
                property string name: ""
                property string description: ""
                property string lastChannel: "user1"
                property bool sendNotification: true
                property bool saveStream: true
                property real gain: 1.0
                // ISO datetime string, "" when no cooldown is active -
                // project-description.md #10.1's per-session broadcast
                // limit for temporaryContributor. Persisted (not just an
                // in-memory property) so the cooldown survives an app
                // restart too, not just staying within one run.
                property string temporaryCooldownUntil: ""
            }

            // Forces temporaryCooldownRemainingSeconds below to
            // re-evaluate once a second - a plain Date.now()-based
            // computation has no QML property to bind to, so without this
            // tick it would only ever update when something else happened
            // to touch the UI.
            property int _nowTick: 0
            Timer {
                interval: 1000
                running: root.isTemporaryContributor
                repeat: true
                onTriggered: parent._nowTick++
            }

            readonly property real temporaryCooldownRemainingSeconds: {
                // References _nowTick (unused otherwise) purely so this
                // binding re-evaluates on the Timer's tick above - a plain
                // Date.now()-based computation has no QML property of its
                // own to bind to.
                if (_nowTick < 0 || !root.isTemporaryContributor || !broadcastSettings.temporaryCooldownUntil)
                    return 0;
                const until = new Date(broadcastSettings.temporaryCooldownUntil).getTime();
                return Math.max(0, (until - Date.now()) / 1000);
            }

            // Called on *any* end of a temporaryContributor's broadcast -
            // reaching the time limit (auto-stop, below) or a manual Stop
            // press (the Start/Stop Button's onClicked) both count as using
            // up the session, so the cooldown starts either way. Otherwise
            // someone could just stop manually just before the limit and
            // immediately start a fresh full-length session, defeating the
            // whole point of the limit.
            function endTemporaryBroadcastSession() {
                if (root.isTemporaryContributor) {
                    broadcastSettings.temporaryCooldownUntil =
                        new Date(Date.now() + root.temporaryBroadcastLimitSeconds * 1000).toISOString();
                }
            }

            // Force-stops a temporaryContributor's broadcast once it hits
            // the time limit - icecastBroadcaster.elapsedSeconds already
            // ticks every second (see the existing elapsed-time Label
            // below), so this just watches it rather than running a
            // second independent timer.
            Connections {
                target: icecastBroadcaster
                function onElapsedSecondsChanged() {
                    if (root.isTemporaryContributor && icecastBroadcaster.broadcasting
                            && icecastBroadcaster.elapsedSeconds >= root.temporaryBroadcastLimitSeconds) {
                        icecastBroadcaster.stopBroadcast();
                        endTemporaryBroadcastSession();
                    }
                }
            }

            // Restores the last-used gain onto the C++ broadcaster - m_gain
            // itself defaults to 1.0 and isn't persisted there, only here in
            // Settings, same division of responsibility as the other fields
            // above (broadcastSettings holds the value, the checkboxes/
            // fields push it into icecastBroadcaster).
            Component.onCompleted: icecastBroadcaster.gain = broadcastSettings.gain


            ComboBox {
                id: channelCombo
                Layout.fillWidth: true
                visible: !icecastBroadcaster.broadcasting
                enabled: !icecastBroadcaster.broadcasting
                model: root.channelNames
                currentIndex: Math.max(0, root.channelNames.indexOf(broadcastSettings.lastChannel))
                onActivated: broadcastSettings.lastChannel = channelCombo.currentText
                delegate: ItemDelegate {
                    width: channelCombo.width
                    text: modelData
                    enabled: !root.isChannelOccupied(modelData)
                }

                // ComboBox has no built-in placeholderText equivalent (unlike
                // TextField above), so this mimics one by hand: a small
                // caption straddling the control's top border - anchoring
                // verticalCenter to parent.top centers it exactly on the
                // border line, and the background rectangle "cuts" through
                // that line the same way Material's own outlined-field
                // placeholder does, rather than just overlapping it.
                Label {
                    text: qsTr("Channel:")
                    font.pointSize: 10
                    color: Material.frameColor
                    padding: 2
                    background: Rectangle { color: Material.background }
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.top
                }


                // Refresh on open instead of a separate refresh button -
                // same pattern as PlayerBar.qml's channel combobox.
                Connections {
                    target: channelCombo.popup
                    function onOpened() { icecastBroadcaster.refreshOccupiedChannels(); }
                }
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                visible: !icecastBroadcaster.broadcasting
                placeholderText: qsTr("Title")
                enabled: !icecastBroadcaster.broadcasting
                text: broadcastSettings.name
                onTextChanged: broadcastSettings.name = text
            }

            TextField {
                id: descriptionField
                Layout.fillWidth: true
                visible: !icecastBroadcaster.broadcasting
                placeholderText: qsTr("Description")
                enabled: !icecastBroadcaster.broadcasting
                text: broadcastSettings.description
                onTextChanged: broadcastSettings.description = text
            }

            // Combined into one Flow (rather than two separate rows) to save
            // vertical space - Flow (unlike RowLayout) wraps onto a second
            // line by itself on narrow/portrait screens instead of forcing
            // either control to shrink or overflow.
            Flow {
                Layout.fillWidth: true
                visible: !icecastBroadcaster.broadcasting
                spacing: 12

                CheckBox {
                    id: sendNotificationCheck
                    text: qsTr("Send notification")
                    enabled: !icecastBroadcaster.broadcasting
                    checked: broadcastSettings.sendNotification
                    onToggled: broadcastSettings.sendNotification = checked
                }

                CheckBox {
                    id: saveStreamCheck
                    text: qsTr("Save stream")
                    enabled: !icecastBroadcaster.broadcasting
                    checked: broadcastSettings.saveStream
                    onToggled: broadcastSettings.saveStream = checked
                }
            }

            // Replaces the Channel/Title/Description/checkboxes controls
            // above (all hidden via visible:!broadcasting) once live - those
            // values can't be changed mid-broadcast anyway (see their own
            // enabled:!broadcasting), so showing the static result instead
            // saves the vertical space they'd otherwise keep occupying.
            Label {
                Layout.fillWidth: true
                visible: icecastBroadcaster.broadcasting
                wrapMode: Text.Wrap
                font.bold: true
                text: qsTr("Broadcasting \"%1\" on %2").arg(nameField.text).arg(channelCombo.currentText)
            }

            // Level meter + gain slider, vertical and side by side so they
            // read like a mixing-desk channel strip - only meaningful while
            // QAudioSource is actually capturing (i.e. while broadcasting),
            // so tucked away here rather than shown alongside the
            // pre-broadcast form controls above.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: icecastBroadcaster.broadcasting
                spacing: 24

                readonly property int meterHeight: 120

                ColumnLayout {
                    spacing: 4

                    Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Level") }

                    // Peak meter fed by IcecastBroadcaster::inputLevel -
                    // reads post-gain samples, so this reflects the same
                    // clipped signal that's actually being streamed, not
                    // the raw mic input.
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: parent.parent.meterHeight
                        radius: 4
                        color: Material.dividerColor
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            radius: 4
                            height: parent.height * icecastBroadcaster.inputLevel
                            color: icecastBroadcaster.inputLevel > 0.9 ? "crimson"
                                   : icecastBroadcaster.inputLevel > 0.7 ? "orange" : "limegreen"

                            Behavior on height { NumberAnimation { duration: 80 } }
                        }
                    }
                }

                ColumnLayout {
                    spacing: 4

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Gain: %1%").arg(Math.round(gainSlider.value * 100))
                    }

                    Slider {
                        id: gainSlider
                        orientation: Qt.Vertical
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: parent.parent.meterHeight
                        from: 0.0
                        to: 2.0
                        value: broadcastSettings.gain
                        onMoved: {
                            broadcastSettings.gain = value;
                            icecastBroadcaster.gain = value;
                        }
                    }
                }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                text: icecastBroadcaster.broadcasting ? qsTr("Stop") : qsTr("Start")
                // channelCombo.currentText defaults to broadcastSettings.lastChannel
                // ("user1" the first time) without the user ever having to open
                // the dropdown - the delegate's `enabled: !root.isChannelOccupied(...)`
                // above only blocks *picking* an occupied channel from the popup, it
                // does nothing for a channel that's already selected by default. Gate
                // Start itself so a busy default channel can't be broadcast to either
                // way - only applies while not already broadcasting, so Stop is always
                // clickable.
                // Also blocked while a temporaryContributor's cooldown is
                // still running - same reasoning as the busy-channel gate
                // above, just a second independent condition.
                enabled: icecastBroadcaster.broadcasting
                         || (!root.isChannelOccupied(channelCombo.currentText) && temporaryCooldownRemainingSeconds <= 0)
                onClicked: {
                    if (icecastBroadcaster.broadcasting) {
                        icecastBroadcaster.stopBroadcast();
                        endTemporaryBroadcastSession();
                    } else {
                        root.errorMessage = "";
                        icecastBroadcaster.startBroadcast(channelCombo.currentText, nameField.text, descriptionField.text, sendNotificationCheck.checked, saveStreamCheck.checked, root.accessToken);
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: !icecastBroadcaster.broadcasting && root.isChannelOccupied(channelCombo.currentText)
                text: qsTr("Channel \"%1\" is busy").arg(channelCombo.currentText)
                color: "crimson"
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: !icecastBroadcaster.broadcasting && temporaryCooldownRemainingSeconds > 0
                text: qsTr("Broadcasting limit reached - try again in %1").arg(root.formatElapsed(temporaryCooldownRemainingSeconds))
                color: "crimson"
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
                text: root.isTemporaryContributor
                      ? qsTr("%1 (%2 left)").arg(root.formatElapsed(icecastBroadcaster.elapsedSeconds))
                            .arg(root.formatElapsed(Math.max(0, root.temporaryBroadcastLimitSeconds - icecastBroadcaster.elapsedSeconds)))
                      : root.formatElapsed(icecastBroadcaster.elapsedSeconds)
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
