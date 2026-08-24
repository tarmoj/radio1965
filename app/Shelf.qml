import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One project-description.md #2.1 "Shelf" - a colored container for all
// shelved events of one type (or folded set of types, see
// CollectionPage.qml's shelfDefs), containing several Boxes - one per
// group-key bucket under the active groupMode ("author"/"month"/"title").
// Meant to be placed inside a GridLayout (Layout.fillWidth/maximumWidth/
// alignment rely on that).
Rectangle {
    id: root

    property string shelfTitle: ""
    property var events: []
    property string groupMode: "month"
    // When false, Boxes collapse to just their header (no Cards
    // underneath) - a compact "just the sorting keys" view
    // (project-description.md #2.1 follow-up).
    property bool showEvents: true
    // Category tint (e.g. CollectionPage.qml's shelfDefs color) - kept as
    // a self-defined property rather than reusing the Rectangle's own
    // `color`, since `color` now stays hardcoded transparent (this Shelf's
    // own fill) while categoryColor still needs forwarding down to Box and
    // its Cards for their tint.
    property color categoryColor: Material.primaryColor

    required property StackView navigationStack
    required property string serverBaseUrl
    required property PlaybackController controller

    // Fills its GridLayout cell up to a reasonable cap rather than
    // stretching indefinitely on wide screens, and never stretches
    // vertically to match a taller neighbor in the same row - each Shelf
    // stays as tall as its own content.
    Layout.fillWidth: true
    Layout.maximumWidth: 420
    Layout.alignment: Qt.AlignTop

    visible: root.events.length > 0
    implicitHeight: root.visible ? (contentColumn.implicitHeight + 24) : 0
    color: "transparent"
    radius: 8
    border.width: 2
    border.color: root.categoryColor


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

    // One entry per group-key bucket ({ headerText, items }) - each becomes
    // one Box. Recomputed whenever events/groupMode change.
    readonly property var groupedBoxes: {
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

        return keys.map(key => ({
            headerText: key,
            items: buckets[key].items.slice().sort((a, b) => (a.title || "").localeCompare(b.title || ""))
        }));
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
            id: boxesColumn
            Layout.fillWidth: true
            spacing: 8

            add: Transition {
                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 200 }
            }

            Repeater {
                model: root.groupedBoxes

                delegate: Box {
                    required property var modelData

                    width: boxesColumn.width
                    headerText: modelData.headerText
                    items: modelData.items
                    showEvents: root.showEvents
                    // Lighter than the category tint so Cards read as
                    // distinct from the shelf's (transparent) background,
                    // while still carrying the category color.
                    cardColor: Qt.lighter(root.categoryColor, 1.25)
                    cardBorderColor: root.categoryColor
                    navigationStack: root.navigationStack
                    serverBaseUrl: root.serverBaseUrl
                    controller: root.controller
                }
            }
        }
    }
}
