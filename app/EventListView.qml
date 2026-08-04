import QtQuick
import QtQuick.Controls

// One tab's worth of the feed ("New Arrivals" or "Collection") -
// project-description.md #2.1. Navigation on tap pushes onto the
// enclosing StackView (see Main.qml's feedComponent).
Item {
    id: root

    property var eventsModel
    // Passed in explicitly: "stackView"/"app" are ids local to Main.qml's
    // document scope, invisible from this separate .qml file, and the
    // StackView.view attached property is only set on the item actually
    // pushed onto the StackView (feedComponent's ColumnLayout), not on
    // EventListView, which sits two levels deeper inside SwipeView.
    // Named differently from Main.qml's "stackView" id: writing
    // `EventListView { stackView: stackView }` with a same-named property
    // would resolve the right-hand side to this instance's own property
    // first (local scope wins over outer ids), causing a self-referencing
    // binding loop instead of picking up the outer StackView.
    required property StackView navigationStack

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 8
        model: root.eventsModel
        spacing: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: EventDelegate {
            // eventId/eventType/title/summary/url/tags/status are populated
            // automatically: their names match NotificationManager's role
            // names exactly (see notificationmanager.cpp roleNames()).

            onArticleRequested: (url, title) =>
                root.navigationStack.push(Qt.resolvedUrl("WebViewPage.qml"),
                                     { pageUrl: url, pageTitle: title })

            onPlayerRequested: (url, title, isLive) =>
                root.navigationStack.push(Qt.resolvedUrl("PlayerPage.qml"),
                                     { mediaUrl: url, mediaTitle: title, isLive: isLive })
        }
    }
}
