import QtQuick
import QtQuick.Controls

// One tab's worth of the feed ("New Arrivals" or "Collection") -
// project-description.md #2.1. Navigation on tap pushes onto the
// enclosing StackView (see Main.qml's feedComponent).
Item {
    id: root

    property var eventsModel

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 8
        model: root.eventsModel
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: EventDelegate {
            eventId: model.id
            eventType: model.type
            title: model.title
            summary: model.summary
            url: model.url
            tags: model.tags
            status: model.status

            onArticleRequested: (url, title) =>
                root.StackView.view.push(Qt.resolvedUrl("WebViewPage.qml"),
                                          { pageUrl: url, pageTitle: title })

            onPlayerRequested: (url, title, isLive) =>
                root.StackView.view.push(Qt.resolvedUrl("PlayerPage.qml"),
                                          { mediaUrl: url, mediaTitle: title, isLive: isLive })
        }
    }
}
