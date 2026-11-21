import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Block author" action (App Store 1.2 UGC compliance) - hides the
// author's posts from this listener's feed instantly (local-only,
// NotificationManager::blockAuthor()) and notifies the developer for
// review (EventsApiClient::reportEvent() with reason "blocked"), same as
// Report. No account/login required - works for anonymous listeners.
// Instantiated once in Main.qml; emits blocked(authorId) so Main.qml can
// persist the id into userSettings.blockedAuthorIds (a different QML
// document, not directly reachable from here).
Dialog {
    id: root
    title: qsTr("Block author")
    modal: true
    anchors.centerIn: parent
    standardButtons: blocked ? Dialog.Close : Dialog.Cancel
    width: Math.min((parent ? parent.width : 420) - 40, 420)

    property string serverUrl: ""

    property int authorId: -1
    property string eventId: ""
    property bool blocked: false

    signal authorBlocked(int authorId)

    function openFor(forAuthorId, forEventId) {
        root.authorId = forAuthorId;
        root.eventId = forEventId;
        root.blocked = false;
        root.open();
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 8
        visible: !root.blocked

        Label {
            text: qsTr("Block this author? Their posts will be hidden from your feed immediately, and the VÄIN team will be notified to review their content.")
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Block")
            onClicked: {
                notificationManager.blockAuthor(root.authorId);
                eventsApiClient.reportEvent(root.serverUrl, root.eventId, "blocked", "");
                root.authorBlocked(root.authorId);
                root.blocked = true;
            }
        }
    }

    Label {
        width: root.availableWidth
        wrapMode: Text.Wrap
        visible: root.blocked
        text: qsTr("Author blocked - their posts are hidden from your feed.")
    }
}
