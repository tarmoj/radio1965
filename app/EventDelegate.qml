import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One row in the "New Arrivals"/"Collection" lists (project-description.md
// #2.1). Tap behavior depends on `type`: "text" expands the summary
// in place, "article"/"webcontent" open WebViewPage, and
// "audio"/"video"/"audiostream"/"videostream" open PlayerPage.
ItemDelegate {
    id: root

    required property string eventId
    required property string eventType
    required property string title
    required property string summary
    required property string url
    required property var tags
    required property string status

    signal articleRequested(string url, string title)
    signal playerRequested(string url, string title, bool isLive)

    property bool expanded: false

    readonly property bool isLive: eventType === "audiostream" || eventType === "videostream"
    readonly property string typeIcon: {
        if (eventType === "audio" || eventType === "audiostream")
            return "qrc:/images/sound.svg";
        if (eventType === "video" || eventType === "videostream")
            return "qrc:/images/play.svg";
        return "";
    }

    width: ListView.view ? ListView.view.width : implicitWidth
    height: column.implicitHeight + 24

    onClicked: {
        switch (eventType) {
        case "article":
        case "webcontent":
            articleRequested(url, title);
            break;
        case "audio":
        case "video":
        case "audiostream":
        case "videostream":
            playerRequested(url, title, isLive);
            break;
        default:
            expanded = !expanded;
        }
    }

    contentItem: ColumnLayout {
        id: column
        anchors.margins: 12
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Image {
                source: root.typeIcon
                visible: root.typeIcon.length > 0
                sourceSize.width: 16
                sourceSize.height: 16
            }

            Label {
                text: root.title
                font.bold: true
                font.pointSize: 13
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Label {
                visible: root.isLive
                text: qsTr("LIVE")
                color: "crimson"
                font.bold: true
                font.pointSize: 10
            }
        }

        Label {
            text: root.summary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            visible: root.eventType !== "text" || root.expanded
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4
            visible: root.tags.length > 0

            Repeater {
                model: root.tags
                delegate: Rectangle {
                    radius: 8
                    color: Material.accentColor
                    implicitHeight: tagLabel.implicitHeight + 4
                    implicitWidth: tagLabel.implicitWidth + 12

                    Label {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: modelData
                        font.pointSize: 9
                    }
                }
            }
        }
    }

    background: Rectangle {
        radius: 5
        color: Material.backgroundColor.lighter()
        border.width: 1
        border.color: Material.primaryColor.lighter()
    }
}
