import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs
import QtCore


ApplicationWindow {
    id: app
    width: 480
    height: 640
    visible: true
    property string version: "0.5.3"
    title: qsTr("Radio 1965") + " v" + version
    color: Material.background

    property color backgroundEndColor: "darkgreen"

    // icecastBroadcaster is only registered as a context property on
    // builds with RADIO65_ENABLE_BROADCAST (see app/CMakeLists.txt) -
    // guarded the same way BroadcastPage.qml already does, so this stays
    // safe even if a future platform ends up without it.
    readonly property bool broadcastAvailable: typeof icecastBroadcaster !== "undefined"
    readonly property bool isBroadcasting: app.broadcastAvailable && icecastBroadcaster.broadcasting

    Settings {
        id: appSettings
        property string serverUrl: "https://live.uuu.ee/radio1965/api"
    }

    Component.onCompleted: {
        eventsApiClient.fetchEvents(appSettings.serverUrl);
    }

    // Push is FYI-only (project-description.md #5): NotificationManager
    // never mutates the event list from a push payload itself - any push
    // arrival (foreground, background, or a notification tap while the app
    // was already running) just re-fetches the real list from the server,
    // same as the manual refresh button.
    Connections {
        target: notificationManager
        function onRefreshRequested() {
            eventsApiClient.fetchEvents(appSettings.serverUrl);
        }
    }

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: Material.backgroundColor }
            GradientStop { position: 0.6; color: Material.backgroundColor }
            GradientStop { position: 0.8; color: backgroundEndColor.darker() }
            GradientStop { position: 1.0; color: backgroundEndColor }
        }
    }

    flags: Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint

    header: ToolBar {
        id: toolBar
        width: parent.width

        implicitHeight: contentItem.implicitHeight + topPadding + bottomPadding

        background: Rectangle {color: "transparent" }

        topPadding: parent.SafeArea ? parent.SafeArea.margins.top : 10
        bottomPadding: 10

        contentItem:  Item {
            anchors.topMargin: 10
            implicitHeight: titleLabel.implicitHeight + 10

            Label {
                id: titleLabel
                anchors.centerIn: parent
                text: title
                font.pointSize: 16
                font.bold: true
                horizontalAlignment: Qt.AlignHCenter

            }

            ToolButton {
                id: menuButton

                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                icon.source: "qrc:/images/menu.svg"
                onClicked: drawer.opened ? drawer.close() : drawer.open()
            }

            ToolButton {
                id: refreshButton

                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                //text: "⟳"
                icon.source: "qrc:/images/refresh.svg"
                onClicked: eventsApiClient.fetchEvents(appSettings.serverUrl)
            }
        }
    }

    Drawer {
        id: drawer
        width: Math.min(Math.max(app.width * 0.7, 360), app.width - 24)
        height: app.height
        //y: toolBar.height
        property int marginLeft: 20

        background: Rectangle {
            anchors.fill:parent;
            color: Material.backgroundColor.lighter()
        }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            // contentWidth: availableWidth

            ColumnLayout {
                width: parent.width //  availableWidth
                spacing: 10

                MenuItem {
                    text: qsTr("Something")
                    onTriggered: {
                        console.log("Something clicked")
                    }                }



                MenuItem {
                    text: qsTr("Info")
                    onTriggered: {
                        infoDialog.open()
                        drawer.close()
                    }
                }

            }
        }

    }

    Dialog {
        id: infoDialog
        title: qsTr("About Radio 1965")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close

        ColumnLayout {
            spacing: 8
            width: Math.min(app.width - 40, 420)

            // Label {
            //     text: qsTr("Radio 1965 %1").arg(version)
            //     font.bold: true
            //     font.pointSize: 16
            // }

            Label {
                text: qsTr("Info comes here.")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            Label {
                text: qsTr("Based on Qt Framework — qt.io")
                font.italic: true
            }

            Label {
                text: qsTr("© Tarmo Johannes\ntrmjhnns@gmail.com")
                font.pointSize: 10
            }
        }
    }

    // Instantiated exactly once here and threaded down explicitly to
    // PlayerBar, VideoPage (as a pushed initial property) and both
    // EventListView instances - see PlaybackController.qml for why this is
    // plain explicit passing rather than `pragma Singleton` global access.
    PlaybackController {
        id: playbackController
    }

    // PlayerBar sits above the StackView (not inside feedComponent) so it
    // stays visible across tab switches and over pushed pages (WebViewPage,
    // VideoPage).
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PlayerBar {
            Layout.fillWidth: true
            controller: playbackController
        }

        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: feedComponent
        }
    }

    // Pushes/pops VideoPage.qml as the currently-playing media's video
    // track appears/disappears - covers both video files and a
    // (hypothetical, future) video stream the same way. Tracked with an
    // explicit bool rather than sniffing stackView.currentItem's type, so
    // a manual pop by the user (VideoPage's back button) doesn't get
    // immediately re-pushed - onHasVideoChanged only fires on a genuine
    // change, not continuously.
    property bool videoPageOpen: false

    Connections {
        target: playbackController.player
        function onHasVideoChanged() {
            if (playbackController.player.hasVideo && !app.videoPageOpen) {
                stackView.push(Qt.resolvedUrl("VideoPage.qml"), { controller: playbackController });
                app.videoPageOpen = true;
            } else if (!playbackController.player.hasVideo && app.videoPageOpen) {
                stackView.pop();
                app.videoPageOpen = false;
            }
        }
    }

    Component {
        id: feedComponent

        ColumnLayout {
            spacing: 0

            TabBar {
                id: tabBar
                Layout.fillWidth: true

                TabButton { icon.source: "qrc:/images/home.svg"   /*text: qsTr("New Arrivals")*/ }
                TabButton { icon.source: "qrc:/images/cards_stack.svg" /*text: qsTr("Collection")*/ }
                TabButton {
                    id: broadcastTabButton
                    icon.source: "qrc:/images/broadcast.svg" /*text: qsTr("Broadcast")*/
                    icon.color: app.isBroadcasting ? "crimson" : broadcastTabButton.palette.windowText

                    // Small blinking "recording" dot overlay, on-air only -
                    // declared as a plain child of the TabButton control,
                    // which Qt Quick Controls renders as an overlay on top
                    // of its own contentItem (the usual way to badge a
                    // control without touching its template).
                    Rectangle {
                        id: broadcastDot
                        width: 8
                        height: 8
                        radius: 4
                        color: "crimson"
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        visible: app.isBroadcasting

                        SequentialAnimation on opacity {
                            running: broadcastDot.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 500 }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 500 }
                        }
                    }
                }
            }

            SwipeView {
                id: swipeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex
                onCurrentIndexChanged: tabBar.currentIndex = currentIndex

                EventListView { eventsModel: newEventsModel; navigationStack: stackView; serverBaseUrl: appSettings.serverUrl; controller: playbackController }
                CollectionPage { navigationStack: stackView; serverBaseUrl: appSettings.serverUrl; controller: playbackController }
                BroadcastPage {}


            }
        }
    }

}
