import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One row in the "New Arrivals"/"Collection" lists (project-description.md
// #2.1). Tap behavior depends on `type`: "text" expands the summary
// in place, "article"/"webcontent" open WebViewPage, and
// "audio"/"video"/"livestream"/"streamrecording" hand off to
// PlaybackController (the persistent PlayerBar strip, see
// Main.qml/PlaybackController.qml). "streamrecording" is a finished
// "Save stream" livestream recording (server/icecast_on_disconnect.sh's
// finalize-recording call, project-description.md #8.2.1) - deliberately
// not "livestream" (see isLive below) and not "audio" (kept distinct from
// readymade/uploaded audio - see CollectionPage.qml's shelfDefs).
ItemDelegate {
    id: root

    required property string eventId
    required property string eventType
    required property string title
    required property string summary
    required property string url
    required property var tags
    required property string status
    required property var payload

    // Joomla-sourced "article" events carry the numeric Joomla article id
    // in payload.article_id (see server/joomla_importer.py); "webcontent"
    // events have no such id and keep loading `url` directly.
    readonly property int articleId: (payload && payload.article_id !== undefined) ? payload.article_id : 0

    signal articleRequested(string url, string title, int articleId, bool isJoomlaArticle)
    signal playerRequested(string url, string title, string summary, bool isLive)

    property bool expanded: false

    // Card.qml (used by Box.qml/SearchResultsPage.qml - i.e. Collection and
    // search, the "boxed" contexts) sets this true so every type collapses
    // to title-only by default with an explicit expand button, rather than
    // this delegate's plain EventListView.qml ("New Arrivals") behavior
    // below where only "text" events start collapsed and everything else
    // always shows its summary.
    property bool showExpandToggle: false

    readonly property bool isLive: eventType === "livestream"

    // Distinct from publish_at (when the card/notification appears):
    // payload.startsAt is when the broadcast itself is scheduled to start,
    // entered in the editor's livestream-only "Starts at" field.
    readonly property string startsAt: (payload && payload.startsAt) ? payload.startsAt : ""
    readonly property string startsAtDisplay: {
        if (!startsAt)
            return "";
        const parsed = new Date(startsAt);
        return isNaN(parsed.getTime()) ? "" : Qt.formatDateTime(parsed, "d MMM yyyy, HH:mm");
    }
    readonly property string typeIcon: {
        if (eventType === "audio" || eventType === "streamrecording")
            return "qrc:/images/sound.svg";
        if (eventType === "video" || eventType === "livestream")
            return "qrc:/images/play.svg";
        return "";
    }

    width: ListView.view ? ListView.view.width : implicitWidth
    height: column.implicitHeight + 24
    clip: true

    onClicked: {
        switch (eventType) {
        case "article":
            articleRequested(url, title, root.articleId, true);
            break;
        case "webcontent":
            articleRequested(url, title, 0, false);
            break;
        case "audio":
        case "video":
        case "livestream":
        case "streamrecording":
            playerRequested(url, title, summary, isLive);
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
                // Layout.minimumWidth defaults to implicitWidth, which for
                // text is its unwrapped single-line width - without this,
                // the RowLayout (and everything above it) gets forced
                // wider to fit a long title instead of letting it wrap.
                Layout.minimumWidth: 0
            }

            Label {
                visible: root.isLive
                text: qsTr("LIVE")
                color: "crimson"
                font.bold: true
                font.pointSize: 10
            }

            // Own click target, independent of onClicked above (which is
            // claimed by play/navigate for most types) - AbstractButton
            // controls grab the press themselves, so tapping this doesn't
            // also fire the delegate's own onClicked underneath it.
            ToolButton {
                visible: root.showExpandToggle && root.summary.length > 0
                icon.source: root.expanded ? "qrc:/images/arrow_drop_up.svg" : "qrc:/images/arrow_drop_down.svg"
                implicitWidth: 28
                implicitHeight: 28
                onClicked: root.expanded = !root.expanded
            }
        }

        Label {
            text: qsTr("Starts: ") + root.startsAtDisplay
            visible: root.isLive && root.startsAtDisplay !== ""
            font.pointSize: 11
            color: Material.accentColor
            Layout.fillWidth: true
        }

        Label {
            text: root.summary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            // showExpandToggle contexts (Collection/search) collapse every
            // type to title-only by default, not just "text" - see the
            // expand ToolButton above.
            visible: root.showExpandToggle ? root.expanded : (root.eventType !== "text" || root.expanded)
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4
            visible:  false //  (root.tags ? root.tags.length : 0) > 0

            Repeater {
                model: root.tags || []
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
