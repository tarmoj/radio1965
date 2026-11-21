import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Report" action on an Event (App Store 1.2 UGC compliance) - emails
// config.FEEDBACK_EMAIL via EventsApiClient::reportEvent(), reviewed by a
// manager who can remove the content/ban the author within 24h using the
// already-existing manager/index.html tools. Instantiated once in
// Main.qml, reached from EventDelegate.qml via the Window attached
// property (Window.window.reportDialog).
Dialog {
    id: root
    title: qsTr("Report this post")
    modal: true
    anchors.centerIn: parent
    standardButtons: sent ? Dialog.Close : Dialog.Cancel
    width: Math.min((parent ? parent.width : 420) - 40, 420)

    // Set once by Main.qml at instantiation (appConfig.serverUrl lives in a
    // different QML document, so it can't be referenced directly here).
    property string serverUrl: ""

    property string eventId: ""
    property bool sending: false
    property bool sent: false
    property string errorMessage: ""

    function openFor(forEventId) {
        root.eventId = forEventId;
        root.errorMessage = "";
        root.sending = false;
        root.sent = false;
        detailsArea.text = "";
        reasonCombo.currentIndex = 0;
        root.open();
    }

    function submit() {
        root.errorMessage = "";
        root.sending = true;
        eventsApiClient.reportEvent(root.serverUrl, root.eventId, reasonCombo.currentValue, detailsArea.text.trim());
    }

    Connections {
        target: eventsApiClient
        function onReportSubmitted(submittedEventId) {
            if (submittedEventId !== root.eventId)
                return;
            root.sending = false;
            root.sent = true;
        }
        function onReportFailed(failedEventId, errorString) {
            if (failedEventId !== root.eventId)
                return;
            root.sending = false;
            root.errorMessage = qsTr("Could not send the report. Try again later.");
        }
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 8
        visible: !root.sent

        Label {
            text: qsTr("Why are you reporting this post?")
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        ComboBox {
            id: reasonCombo
            Layout.fillWidth: true
            enabled: !root.sending
            textRole: "text"
            valueRole: "value"
            model: [
                { text: qsTr("Objectionable content"), value: "objectionable" },
                { text: qsTr("Abusive behavior"), value: "abusive" },
                { text: qsTr("Other"), value: "other" }
            ]
        }

        TextArea {
            id: detailsArea
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            enabled: !root.sending
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("Details (optional)")
        }

        Label {
            text: root.errorMessage
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            color: "crimson"
            visible: text !== ""
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            BusyIndicator {
                implicitWidth: 20
                implicitHeight: 20
                running: root.sending
                visible: running
            }

            Button {
                text: qsTr("Report")
                enabled: !root.sending
                onClicked: root.submit()
            }
        }
    }

    Label {
        width: root.availableWidth
        wrapMode: Text.Wrap
        visible: root.sent
        text: qsTr("Report sent - thank you. Our team reviews reports and acts on them within 24 hours.")
    }
}
