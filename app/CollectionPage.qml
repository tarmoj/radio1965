import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The "Collection" SwipeView tab (project-description.md #2.1) - shelved
// events grouped into per-type Shelves, each further grouped by
// Author/Month/Title, plus a collapsible search strip that pushes
// SearchResultsPage.qml onto the shared StackView. Replaces the plain
// EventListView the Collection tab used before - "New Arrivals" keeps using
// EventListView unchanged.
Page {
    id: root

    required property StackView navigationStack
    required property string serverBaseUrl
    required property PlaybackController controller

    property string groupMode: "month"
    property bool searchVisible: false

    // Folds server/db.py's 8 EVENT_TYPES into project-description.md's 6
    // shelves - audiostream/videostream (no dedicated shelf in the doc)
    // fold into Audio/Video as the closest semantic match. Colors are a
    // simple hue-per-shelf scheme suited to the app's existing dark
    // background (Main.qml's Material.background gradient).
    readonly property var shelfDefs: [
        { types: ["livestream"], title: qsTr("Live Streams"), color: "#4a1620", border: "#8c2f45" },
        { types: ["audio", "audiostream"], title: qsTr("Audio"), color: "#16304a", border: "#2f5f8c" },
        { types: ["video", "videostream"], title: qsTr("Video"), color: "#2a1a4a", border: "#5b3a8c" },
        { types: ["webcontent"], title: qsTr("Web Content"), color: "#16403c", border: "#2f8c7f" },
        { types: ["article"], title: qsTr("Article"), color: "#4a3416", border: "#8c6a2f" },
        { types: ["text"], title: qsTr("Message"), color: "#2c4a16", border: "#5f8c2f" }
    ]

    property var events: notificationManager.shelvedEvents()

    // Recompute whenever the underlying model changes - same Connections
    // pattern PlaybackController.qml already uses for notificationManager.
    Connections {
        target: notificationManager
        function onDataChanged() { root.events = notificationManager.shelvedEvents(); }
        function onRowsInserted() { root.events = notificationManager.shelvedEvents(); }
        function onRowsRemoved() { root.events = notificationManager.shelvedEvents(); }
    }

    function runSearch() {
        const query = searchField.text.trim();
        if (query.length === 0)
            return;
        root.navigationStack.push(Qt.resolvedUrl("SearchResultsPage.qml"), {
            query: query,
            events: root.events,
            navigationStack: root.navigationStack,
            serverBaseUrl: root.serverBaseUrl,
            controller: root.controller
        });
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.margins: 5

            Label {
                text: qsTr("Collection")
                font.bold: true
                Layout.fillWidth: true
            }

            ToolButton {
                icon.source: "qrc:/images/search.svg"
                onClicked: root.searchVisible = !root.searchVisible
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            visible: root.searchVisible
            spacing: 8

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search title, author, or word…")
                onAccepted: root.runSearch()
            }

            ToolButton {
                icon.source: "qrc:/images/search.svg"
                onClicked: root.runSearch()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label { text: qsTr("Group by:") }

            ButtonGroup { id: groupButtons }

            RadioButton {
                text: qsTr("Author")
                ButtonGroup.group: groupButtons
                checked: root.groupMode === "author"
                onToggled: root.groupMode = "author"
            }
            RadioButton {
                text: qsTr("Month")
                ButtonGroup.group: groupButtons
                checked: root.groupMode === "month"
                onToggled: root.groupMode = "month"
            }
            RadioButton {
                text: qsTr("Title")
                ButtonGroup.group: groupButtons
                checked: root.groupMode === "title"
                onToggled: root.groupMode = "title"
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 12

                Repeater {
                    model: root.shelfDefs
                    delegate: Shelf {
                        shelfTitle: modelData.title
                        color: modelData.color
                        border.color: modelData.border
                        events: root.events.filter(e => modelData.types.includes(e.eventType))
                        groupMode: root.groupMode
                        navigationStack: root.navigationStack
                        serverBaseUrl: root.serverBaseUrl
                        controller: root.controller
                    }
                }

                Label {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Nothing in the Collection yet.")
                    visible: root.events.length === 0
                    opacity: 0.7
                }
            }
        }
    }
}
