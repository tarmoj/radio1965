import QtQuick
import QtQuick.Controls

// The "Box" from project-description.md #2.1 - a shelved-item card with a
// per-shelf color scheme. Extends EventDelegate rather than duplicating its
// click-routing/expand/type-icon logic (article/webcontent -> WebViewPage,
// audio/video/livestream -> PlaybackController, text -> inline expand) -
// only the background styling is overridden here.
EventDelegate {
    id: root

    property color boxColor: Material.backgroundColor.lighter()
    property color boxBorderColor: Material.primaryColor.lighter()

    background: Rectangle {
        radius: 5
        color: root.boxColor
        border.width: 1
        border.color: root.boxBorderColor
    }
}
