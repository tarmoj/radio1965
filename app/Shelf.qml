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
    // When false, only the group headers (e.g. month names, author names,
    // title-letters) are shown, no Box cards underneath - a compact
    // "just the sorting keys" view (project-description.md #2.1 follow-up).
    property bool showEvents: true
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
            const items = buckets[key].items.slice().sort((a, b) => (a.title || "").localeCompare(b.title || ""));
            entries.push({ isHeader: true, headerText: key, items: items });
            if (!root.showEvents)
                continue;
            for (const event of items)
                entries.push({ isHeader: false, event: event });
        }
        return entries;
    }

    // Opens groupPopup for one bucket's worth of events - reached by
    // tapping a group header (e.g. "August 2026", "T"), most useful while
    // showEvents is off and the Boxes themselves aren't rendered inline.
    function openGroupPopup(headerText, items) {
        groupPopup.headerText = headerText;
        groupPopup.groupItems = items;
        groupPopup.open();
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

                        // Opens the full list of this group's events in a
                        // floating popup - the group key itself is the
                        // click target, not the event cards.
                        MouseArea {
                            anchors.fill: parent
                            enabled: entryItem.isHeaderEntry
                            onClicked: root.openGroupPopup(modelData.headerText, modelData.items)
                        }
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

    // Floating list of one group's events (not a StackView push -
    // project-description.md #2.1 asks for "a floating dialog"), opened by
    // tapping a group header - lets the user browse a group's events even
    // while showEvents is off and the Boxes aren't rendered inline.
    Popup {
        id: groupPopup
        parent: root.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min((parent ? parent.width : 400) * 0.9, 480)
        height: Math.min((parent ? parent.height : 600) * 0.8, 640)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string headerText: ""
        property var groupItems: []

        contentItem: ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: groupPopup.headerText
                    font.bold: true
                    font.pointSize: 15
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "✕"
                    onClicked: groupPopup.close()
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    width: groupPopup.width - 32
                    spacing: 6

                    Repeater {
                        model: groupPopup.groupItems

                        delegate: Box {
                            required property var modelData

                            width: parent ? parent.width : implicitWidth
                            eventId: modelData.eventId
                            eventType: modelData.eventType
                            title: modelData.title
                            summary: modelData.summary
                            url: modelData.url
                            tags: modelData.tags
                            status: modelData.status
                            payload: modelData.payload
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
}
