import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One project-description.md #2.1 "Shelf" - a colored container for all
// shelved events of one type (or folded set of types, see
// CollectionPage.qml's shelfDefs), with its Boxes grouped by the active
// groupMode ("author"/"month"/"title"). Meant to be placed inside a
// ColumnLayout (Layout.fillWidth relies on that).
Rectangle {
    id: root

    property string shelfTitle: ""
    property var events: []
    property string groupMode: "month"
    required property StackView navigationStack
    required property string serverBaseUrl
    required property PlaybackController controller

    Layout.fillWidth: true
    visible: root.events.length > 0
    implicitHeight: root.visible ? (contentColumn.implicitHeight + 24) : 0
    radius: 8
    border.width: 1

    function groupKeyFor(event) {
        if (root.groupMode === "author")
            return (event.payload && event.payload.author) ? event.payload.author : qsTr("Unknown");
        if (root.groupMode === "title") {
            const first = (event.title || "").trim().charAt(0).toUpperCase();
            return first || "#";
        }
        // "month" - falls back to publishAt as the closest available
        // stand-in for "creation time" (the API's to_dict() doesn't expose
        // created_at, only publish_at/shelf_at).
        const parsed = new Date(event.publishAt);
        return isNaN(parsed.getTime()) ? qsTr("Unknown date") : Qt.formatDateTime(parsed, "MMMM yyyy");
    }

    // Sortable value per group - lets "month" order chronologically
    // (newest first) rather than alphabetically by the formatted display
    // name, while "author"/"title" just sort by their own key text.
    function groupSortKeyFor(event) {
        if (root.groupMode === "month") {
            const parsed = new Date(event.publishAt);
            return isNaN(parsed.getTime()) ? "" : parsed.toISOString().slice(0, 7); // "YYYY-MM" sorts correctly as text
        }
        return root.groupKeyFor(event);
    }

    // Flattened {isHeader:true, headerText} / {isHeader:false, event}
    // entries - simplest way to render group headers interleaved with
    // Boxes via a single Repeater, recomputed whenever events/groupMode
    // change.
    readonly property var groupedEntries: {
        const buckets = {};
        for (const event of root.events) {
            const key = root.groupKeyFor(event);
            if (!buckets[key])
                buckets[key] = { sortKey: root.groupSortKeyFor(event), items: [] };
            buckets[key].items.push(event);
        }
        const keys = Object.keys(buckets).sort((a, b) => {
            const sa = buckets[a].sortKey, sb = buckets[b].sortKey;
            if (root.groupMode === "month")
                return sa < sb ? 1 : (sa > sb ? -1 : 0); // newest month first
            return sa < sb ? -1 : (sa > sb ? 1 : 0);
        });

        const entries = [];
        for (const key of keys) {
            entries.push({ isHeader: true, headerText: key });
            const items = buckets[key].items.slice().sort((a, b) => (a.title || "").localeCompare(b.title || ""));
            for (const event of items)
                entries.push({ isHeader: false, event: event });
        }
        return entries;
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Label {
            text: root.shelfTitle
            font.bold: true
            font.pointSize: 15
        }

        // Plain Column (a Positioner, unlike ColumnLayout), specifically so
        // add/move Transitions are available - the "simple animation when
        // sorting is changed" ask (project-description.md #2.1) only needs
        // to apply to this reordering region, not the whole Shelf.
        Column {
            id: entriesColumn
            Layout.fillWidth: true
            spacing: 6

            add: Transition {
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 200 }
            }

            Repeater {
                model: root.groupedEntries

                delegate: Item {
                    id: entryItem
                    readonly property bool isHeaderEntry: modelData.isHeader
                    width: entriesColumn.width
                    height: isHeaderEntry ? headerLabel.implicitHeight + 8 : box.height

                    Label {
                        id: headerLabel
                        visible: entryItem.isHeaderEntry
                        text: entryItem.isHeaderEntry ? modelData.headerText : ""
                        font.bold: true
                        font.pointSize: 11
                        opacity: 0.8
                    }

                    Box {
                        id: box
                        visible: !entryItem.isHeaderEntry
                        width: parent.width
                        eventId: !entryItem.isHeaderEntry ? modelData.event.eventId : ""
                        eventType: !entryItem.isHeaderEntry ? modelData.event.eventType : "text"
                        title: !entryItem.isHeaderEntry ? modelData.event.title : ""
                        summary: !entryItem.isHeaderEntry ? modelData.event.summary : ""
                        url: !entryItem.isHeaderEntry ? modelData.event.url : ""
                        tags: !entryItem.isHeaderEntry ? modelData.event.tags : []
                        status: !entryItem.isHeaderEntry ? modelData.event.status : ""
                        payload: !entryItem.isHeaderEntry ? modelData.event.payload : ({})
                        // Lighter than the shelf's own fill so Boxes read
                        // as distinct cards rather than blending into the
                        // shelf background.
                        boxColor: Qt.lighter(root.color, 1.25)
                        boxBorderColor: root.border.color

                        onArticleRequested: (url, title, articleId, isJoomlaArticle) =>
                            root.navigationStack.push(Qt.resolvedUrl("WebViewPage.qml"), {
                                pageUrl: url,
                                pageTitle: title,
                                articleId: isJoomlaArticle ? articleId : 0,
                                serverBaseUrl: root.serverBaseUrl
                            })

                        onPlayerRequested: (url, title, summary, isLive) =>
                            root.controller.playMedia(url, title, summary, isLive)
                    }
                }
            }
        }
    }
}
