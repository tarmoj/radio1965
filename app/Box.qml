import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The "Box" from project-description.md #2.1 - contains several Cards, all
// belonging to the same group-key bucket within a Shelf (e.g. all events
// published in "August 2026", or all whose title starts with "T"). Rounded
// rect, neutral border (the shelf itself carries the category color, not
// the Box) - Cards inside are tinted with cardColor/cardBorderColor,
// forwarded in from Shelf.qml so they still read as belonging to the
// shelf's category.
Rectangle {
    id: root

    required property string headerText
    required property var items
    property bool showEvents: true
    property color cardColor: Material.backgroundColor.lighter()
    property color cardBorderColor: Material.primaryColor.lighter()
    required property StackView navigationStack
    required property string serverBaseUrl
    required property PlaybackController controller

    Layout.fillWidth: true
    // A real `height`, not implicitHeight: Box sits inside Shelf.qml's
    // boxesColumn, a plain Column positioner (not a Layout), which sizes
    // children (and therefore Shelf's own content-driven height) off their
    // actual height, not implicitHeight - needed for Shelf's per-item
    // (non-fixed) height in the Collection grid, so shelves can align to
    // the grid's top rather than all stretching to a fixed size.
    height: contentColumn.implicitHeight + 16
    radius: 6
    color: "transparent"
    //border.width: 1
    //border.color: Material.frameColor

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        Label {
            id: headerLabel
            text: root.headerText
            font.bold: true
            font.pointSize: 11
            opacity: 0.8

            // The group key itself is the click target that opens the
            // floating popup listing this Box's Cards - useful even when
            // showEvents is off and the Cards aren't rendered inline.
            MouseArea {
                anchors.fill: parent
                onClicked: groupPopup.open()
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 6
            visible: root.showEvents

            Repeater {
                model: root.showEvents ? root.items : []

                delegate: Card {
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
                    cardColor: root.cardColor
                    cardBorderColor: root.cardBorderColor

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

    // Floating list of this Box's Cards (not a StackView push -
    // project-description.md #2.1 asks for "a floating dialog"), opened by
    // tapping the header label.
    Popup {
        id: groupPopup
        parent: root.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min((parent ? parent.width : 400) * 0.9, 480)
        height: Math.min((parent ? parent.height : 600) * 0.8, 640)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        contentItem: ColumnLayout {
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: root.headerText
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
                        model: root.items

                        delegate: Card {
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
                            cardColor: root.cardColor
                            cardBorderColor: root.cardBorderColor

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
