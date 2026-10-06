import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Dialogs
import QtCore
import QtQuick.Window
import QtWebView


ApplicationWindow {
    id: app
    width: 480
    height: 640
    visible: true
    property string version: Qt.application.version
    title: qsTr("VÄIN") + " v" + version
    color: Material.background

    //font.family: "monospace"
    //font.pointSize: 12

    property color backgroundEndColor: "#245a28"   // primary container — deep green

    // icecastBroadcaster is only registered as a context property on
    // builds with RADIO65_ENABLE_BROADCAST (see app/CMakeLists.txt) -
    // guarded the same way BroadcastPage.qml already does, so this stays
    // safe even if a future platform ends up without it.
    readonly property bool broadcastAvailable: typeof icecastBroadcaster !== "undefined"
    readonly property bool isBroadcasting: app.broadcastAvailable && icecastBroadcaster.broadcasting

    // Exposed so pushed pages in a *different* QML file (e.g. WebViewPage.qml,
    // reached via the ApplicationWindow.window attached property) can react
    // to the drawer without a direct id reference, which only works within
    // the same document. See WebViewPage.qml's WebView.visible - QtWebView's
    // native content always renders on top of the whole Qt Quick scene
    // (documented Qt limitation, no z value fixes it), so the only way to
    // let the Drawer be usable/visible while an article is open is to
    // temporarily hide the WebView itself while the drawer is open.
    property alias drawerOpened: drawer.opened

    Settings {
        id: appSettings
        property string serverUrl: "https://live.uuu.ee/radio1965/api"
        property bool showInfoOnStartup: true
        // contributor/index.html - register/login/forgot-password page
        // embedded by contributorDialog's WebView below.
        property string contributorWebUrl: "https://eccm.ee/radio1965/contributor/"
    }

    // "Become a Contributor" gate (project-description.md #10) - role is
    // "none"/"pending"/"contributor"/"temporaryContributor"/"manager".
    // "banned" also exists server-side (db.USER_ROLES) but nothing acts on
    // it in the app yet - see checkContributorStatus()'s own comment.
    Settings {
        id: userSettings
        category: "User"
        property string role: "none"
        property string contributorName: ""
        property string contributorEmail: ""
        // Opaque per-account secret from POST /contributors/register -
        // doubles as the credential for checkContributorStatus()'s
        // GET /contributors/status calls. Only ever set for the permanent
        // "Become a Contributor" flow (#10.2) - temporaryContributor
        // (#10.1) has no account/token of its own.
        property string accessToken: ""
    }

    Component.onCompleted: {
        eventsApiClient.fetchEvents(appSettings.serverUrl);
        checkContributorStatus();
        if (appSettings.showInfoOnStartup) {
            infoDialog.showDontShowCheckbox = true;
            infoDialog.open();
        }
    }

    // Polls GET /contributors/status (project-description.md #10.2) to
    // notice a "pending" -> "contributor" transition once the user clicks
    // the emailed confirmation link - the doc's own suggested sync point,
    // "on Refresh events" (called from both here and the header's refresh
    // button below), plus on startup. A no-op whenever there's nothing to
    // check (no token, or role already settled as something other than
    // "pending" - "banned" included, since nothing here acts on it yet).
    function checkContributorStatus() {
        if (userSettings.role !== "pending" || !userSettings.accessToken)
            return;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", appSettings.serverUrl + "/contributors/status?token=" + encodeURIComponent(userSettings.accessToken));
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                const response = JSON.parse(xhr.responseText);
                userSettings.role = response.role;
            }
            // Non-200 (network error, 404 unknown token): leave role as
            // "pending" and silently try again next time - this runs
            // often enough (startup + every refresh) that surfacing a
            // transient failure to the user isn't worth it.
        };
        xhr.send();
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
                onClicked: {
                    eventsApiClient.fetchEvents(appSettings.serverUrl);
                    checkContributorStatus();
                }
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
                    text: qsTr("Become a Contributor / Log in")
                    // Was `!== "contributor"` - now also hidden while
                    // "pending" (see the Label just below) and while
                    // already "manager". Still offered for
                    // temporaryContributor, so upgrading to a real account
                    // is possible. One entry covers both register and
                    // login - contributor/index.html's own views handle
                    // that split (project-description.md #10's "Become a
                    // contributor/Log in" TODO).
                    visible: userSettings.role === "none" || userSettings.role === "temporaryContributor"
                    onTriggered: {
                        contributorDialog.open()
                        drawer.close()
                    }
                }

                Label {
                    text: qsTr("Registration pending - check your email")
                    visible: userSettings.role === "pending"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    opacity: 0.8
                }

                MenuItem {
                    text: qsTr("Temporary contributor")
                    // Hidden once you're already either kind of contributor -
                    // "Become a Contributor" above stays offered even as a
                    // temporaryContributor, so upgrading later is still
                    // possible; this one has nothing left to offer then.
                    visible: userSettings.role === "none"
                    onTriggered: {
                        temporaryContributorDialog.open()
                        drawer.close()
                    }
                }

                MenuItem {
                    text: qsTr("Leave contributor role")
                    visible: userSettings.role !== "none"
                    onTriggered: {
                        userSettings.role = "none"
                        // Stale otherwise - harmless (checkContributorStatus()
                        // only ever fires while role === "pending"), but no
                        // reason to keep it around once the account is
                        // disowned locally.
                        userSettings.accessToken = ""
                        drawer.close()
                    }
                }

                MenuItem {
                    text: qsTr("Info")
                    onTriggered: {
                        infoDialog.showDontShowCheckbox = false;
                        infoDialog.open()
                        drawer.close()
                    }
                }

            }
        }

    }

    Dialog {
        id: infoDialog
        title: qsTr("About VÄIN")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Close
        // Dialog doesn't auto-size itself from an explicit `width:` set on
        // an inner child (that only ever controls the ColumnLayout's own
        // width, not the Dialog's actual content-area/frame) - same fix as
        // contributorDialog below: the width has to go on the Dialog itself.
        width: Math.min(app.width - 40, 420)

        // Only true when this dialog was auto-opened at startup (see
        // Component.onCompleted above) - set back to false whenever it's
        // opened from the drawer's "Info" MenuItem, so the checkbox below
        // (which controls appSettings.showInfoOnStartup, a startup-only
        // concern) doesn't show up in a context where it wouldn't mean
        // anything.
        property bool showDontShowCheckbox: false

        ColumnLayout {
            spacing: 8
            width: infoDialog.availableWidth

            // Label {
            //     text: qsTr("Radio 1965 %1").arg(version)
            //     font.bold: true
            //     font.pointSize: 16
            // }

            Label {
                text: qsTr(`
Väin (Estonian for 'strait'), a seemingly narrow body of water with a depth undetectable from the surface and a layered structure that constantly varies. It is an intermediate area that bridges one time to another.

VÄIN is an app created for the 'Radio Tallinn 1965' project, run by the Estonian Centre for Contemporary Music. It connects not only the past and the present, but also the people using it. Follow or broadcast audio streams, receive notifications about key events, and read, listen to, watch, or share something meaningful. Be connected with ECCM.
                           `)
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

            CheckBox {
                text: qsTr("Don't show on startup")
                visible: infoDialog.showDontShowCheckbox
                checked: !appSettings.showInfoOnStartup
                onToggled: appSettings.showInfoOnStartup = !checked
            }
        }
    }

    Dialog {
        id: contributorDialog
        title: qsTr("Become a Contributor / Log in")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        // Dialog doesn't auto-size itself from an explicit `width:` set on
        // an inner child - same fix as infoDialog above. Taller than the
        // other dialogs here since it now hosts a full web page rather
        // than a few fields.
        width: Math.min(app.width - 40, 480)
        height: Math.min(app.height - 80, 640)

        property bool loading: true

        // Reload the page fresh on every open - including after a
        // previous attempt handed off a result - so it always starts back
        // at the register view.
        onOpened: {
            contributorDialog.loading = true
            // "?embed=app" tells contributor/index.html to hand its result
            // back via the "#result=" URL-fragment trick below instead of
            // redirecting to the editor page (which only makes sense for a
            // standalone browser visit).
            contributorWebView.url = appSettings.contributorWebUrl + "?embed=app"
        }

        // contributor/index.html (register/login/forgot-password) embedded
        // via WebView instead of native fields - project-description.md
        // #10's "Become a contributor/Log in" TODO, plus "also on the web".
        // QtWebView has no JS bridge (unlike WebEngine's WebChannel), so
        // the page hands results back by setting its own URL fragment to
        // "#result=<json>" instead of navigating - caught below via
        // onUrlChanged, with no extra request/reload involved.
        WebView {
            id: contributorWebView
            anchors.fill: parent
            visible: !contributorDialog.loading

            onLoadingChanged: function(loadRequest) {
                if (loadRequest.status !== WebView.LoadStartedStatus)
                    contributorDialog.loading = false
            }

            onUrlChanged: {
                const urlString = contributorWebView.url.toString();
                const marker = "#result=";
                const index = urlString.indexOf(marker);
                if (index === -1)
                    return;
                const payload = JSON.parse(decodeURIComponent(urlString.substring(index + marker.length)));
                userSettings.role = payload.role;
                userSettings.accessToken = payload.token;
                if (payload.name)
                    userSettings.contributorName = payload.name;
                if (payload.email)
                    userSettings.contributorEmail = payload.email;
                contributorDialog.close();
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: contributorDialog.loading
            visible: running
        }
    }

    Dialog {
        id: temporaryContributorDialog
        title: qsTr("Temporary contributor")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel
        // Same reasoning as contributorDialog above - width has to go on
        // the Dialog itself, not an inner child.
        width: Math.min(app.width - 40, 420)

        property string errorMessage: ""
        property bool verifying: false

        // Same reasoning as contributorDialog's onOpened above.
        onOpened: {
            tempNameField.text = ""
            tempPasswordField.text = ""
            temporaryContributorDialog.errorMessage = ""
            temporaryContributorDialog.verifying = false
        }

        // Checked server-side, not locally (project-description.md #10.1
        // item 1 is explicit about this - unlike contributorDialog's still-
        // placeholder "1965" check above) against
        // config.TEMPORARY_CONTRIBUTOR_PASSWORD_PATH, a plain-text file an
        // admin can edit directly on the server - see server/main.py's
        // verify_temporary_contributor_password(). Plain XMLHttpRequest
        // here rather than routing through EventsApiClient (C++): this is
        // the only place in the app that needs a one-off POST, so adding a
        // whole C++ method (+ rebuild) for it isn't worth it.
        function submit() {
            temporaryContributorDialog.errorMessage = "";
            temporaryContributorDialog.verifying = true;
            const xhr = new XMLHttpRequest();
            xhr.open("POST", appSettings.serverUrl + "/temporary-contributor/verify");
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE)
                    return;
                temporaryContributorDialog.verifying = false;
                if (xhr.status === 200) {
                    userSettings.role = "temporaryContributor";
                    userSettings.contributorName = tempNameField.text;
                    temporaryContributorDialog.close();
                } else if (xhr.status === 403) {
                    temporaryContributorDialog.errorMessage = qsTr("Incorrect password.");
                } else {
                    temporaryContributorDialog.errorMessage = qsTr("Could not reach the server. Try again later.");
                }
            };
            xhr.send(JSON.stringify({ password: tempPasswordField.text }));
        }

        ColumnLayout {
            spacing: 8
            width: temporaryContributorDialog.availableWidth

            // No email field - project-description.md #10.1 item 1
            // explicitly says temporary contributors don't need to give one.
            TextField {
                id: tempNameField
                Layout.fillWidth: true
                enabled: !temporaryContributorDialog.verifying
                placeholderText: qsTr("Name")
            }

            TextField {
                id: tempPasswordField
                Layout.fillWidth: true
                enabled: !temporaryContributorDialog.verifying
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
            }

            Label {
                text: temporaryContributorDialog.errorMessage
                color: "crimson"
                visible: text !== ""
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                BusyIndicator {
                    implicitWidth: 20
                    implicitHeight: 20
                    running: temporaryContributorDialog.verifying
                    visible: running
                }

                Button {
                    text: qsTr("Submit")
                    enabled: !temporaryContributorDialog.verifying
                    onClicked: temporaryContributorDialog.submit()
                }
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
            // Hidden (not just occluded) while VideoPage is fullscreen so
            // StackView/VideoPage can actually claim its space too - a
            // Layout child's visible:false is excluded from space
            // allocation. Keyed off the window's own visibility rather
            // than a new custom signal/alias: Window.FullScreen is
            // currently only ever entered via VideoPage.qml's own toggle,
            // so this stays correct without a new cross-file channel.
            visible: app.visibility !== Window.FullScreen
        }

        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: feedComponent

            // WebViewPage.qml's QtWebView content renders via a native
            // platform view (Android's real WebView widget / iOS's
            // WKWebView) composited on top of the entire Qt Quick scene -
            // it's not a real scene-graph item, so no z value can put the
            // Drawer (or any QML Popup/Overlay) above it once it's pushed.
            // Closing the drawer whenever the current page changes sidesteps
            // that platform limitation instead of trying to out-z-order it.
            onCurrentItemChanged: if (drawer.opened) drawer.close()
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
                    icon.color: app.isBroadcasting ? "crimson" : Material.foreground

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
                clip: true
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex
                onCurrentIndexChanged: tabBar.currentIndex = currentIndex

                EventListView {
                    eventsModel: newEventsModel;
                    navigationStack: stackView;
                    serverBaseUrl: appSettings.serverUrl;
                    controller: playbackController
                }

                CollectionPage {
                    clip: true // this did the tric of overflowing to next page
                    navigationStack: stackView;
                    serverBaseUrl: appSettings.serverUrl;
                    controller: playbackController
                }

                BroadcastPage {
                    // "manager" per project-description.md #10.2: "Only
                    // people with role 'contributor', 'temporaryContributor'
                    // and 'manager' can broadcast". Nothing assigns
                    // "manager" yet (manual DB update only - see the
                    // registration plan's "Out of scope" notes), but the
                    // gate itself should already respect it.
                    isContributor: userSettings.role === "contributor" || userSettings.role === "temporaryContributor"
                                   || userSettings.role === "manager"
                    isTemporaryContributor: userSettings.role === "temporaryContributor"
                }



            }
        }
    }

}
