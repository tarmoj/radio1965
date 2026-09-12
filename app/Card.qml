import QtQuick
import QtQuick.Controls

// The "Card" from project-description.md #2.1 - the smallest element, a
// delegate for viewing one event. Extends EventDelegate rather than
// duplicating its click-routing/expand/type-icon logic (article/webcontent
// -> WebViewPage, audio/video/livestream -> PlaybackController, text ->
// inline expand) - only the background styling is overridden here. Several
// Cards are grouped into a Box (Box.qml), several Boxes make up a Shelf
// (Shelf.qml).
EventDelegate {
    id: root

    property color cardColor: Material.backgroundColor.lighter()
    property color cardBorderColor: Material.primaryColor.lighter()

    background: Rectangle {
        radius: 5
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorderColor
    }
}
