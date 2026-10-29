import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebView

// Renders "article"/"webcontent" events (project-description.md #2).
// "article" events (Joomla-sourced) fetch rendered HTML live from the
// server's GET /articles/{id} proxy (server/main.py, which itself fetches
// live from Joomla - nothing is stored server-side either way) and render
// it as a data: URI. "webcontent" events have no Joomla article id and keep
// loading `pageUrl` directly, as before.
//
// Not using WebView.loadHtml(html, baseUrl): Qt's Android WebView backend
// has a bug where content loaded that way renders as literal
// percent-encoded text instead of being decoded (desktop is unaffected).
// Loading a "data:text/html;...,<encoded html>" URL via the normal `url`
// property goes through WebView's regular navigation path instead of that
// broken loadData()/loadDataWithBaseURL() JNI bridge, and works on both.
// baseUrl is no longer needed either way: the server already rewrites the
// article's image/link URLs to be absolute (see _absolutize_urls() in
// server/main.py), so there's nothing left for a baseUrl to resolve.
Page {
    id: root

    property string pageUrl: ""
    property string pageTitle: ""
    property int articleId: 0
    property string serverBaseUrl: ""

    property bool loading: false
    property string errorMessage: ""

    // QtWebView's native content (Android's real WebView widget / iOS's
    // WKWebView) always renders on top of the entire Qt Quick scene,
    // documented Qt limitation with no z-value fix - so the app's Drawer
    // (Main.qml) can never render above it while it's visible. Reached via
    // the ApplicationWindow.window attached property since Main.qml's
    // `drawer` id isn't reachable from this separate file - see Main.qml's
    // `property alias drawerOpened: drawer.opened`. Hiding the WebView
    // while the drawer is open is the only way to make the drawer usable
    // on top of an open article, since it can't be layered above. The same
    // goes for PlayerBar's channel/recent-media dropdowns - Main.qml's
    // `overlayOpen` covers both.
    readonly property bool drawerOpen: ApplicationWindow.window ? ApplicationWindow.window.overlayOpen : false

    background: Rectangle { color: "transparent" }

    header: ToolBar {
        background: Rectangle { color: "transparent" }

        RowLayout {
            anchors.fill: parent

            ToolButton {
                text: "←"
                onClicked: root.StackView.view.pop()
            }

            Label {
                text: root.pageTitle
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    WebView {
        id: webView
        // Reserves a thin strip at the left edge outside the native
        // WebView's own bounds - like any native-composited content, it
        // always wins touch arbitration within its own rectangle (same
        // limitation as the drawerOpen handling below), so an edge-swipe
        // gesture detector placed on `root` would never see a touch that
        // starts over the WebView itself. edgeSwipeHandler below only ever
        // needs to see presses starting in this gutter anyway.
        readonly property int edgeGutter: 16
        x: edgeGutter
        // Collapsing width/height to 0 (not just toggling `visible`) while
        // the drawer is open: QtWebView's native content is embedded via
        // QQuickWindowContainer, and on iOS specifically the container's
        // `visible` propagation to the underlying WKWebView-backed window
        // has been reported unreliable (the WebView just stays on top
        // regardless - see Qt forum thread 77281). Its width/height changes
        // are forwarded straight through to the native window's own
        // setWidth/setHeight though, so a zero-sized WebView reliably has
        // nothing left to render/hit-test even when `visible` alone
        // wouldn't have hidden it.
        width: root.drawerOpen ? 0 : parent.width - edgeGutter
        height: root.drawerOpen ? 0 : parent.height
        visible: !root.loading && root.errorMessage === "" && !root.drawerOpen
    }

    // iOS-style "swipe from the left edge to go back" - matches the
    // platform convention (UINavigationController's interactive pop
    // gesture) that this Page otherwise lacks, having only the explicit "←"
    // button above. Only needs to watch the webView.edgeGutter strip left
    // uncovered above; a touch starting further right lands on the native
    // WebView content instead and never reaches this handler.
    DragHandler {
        id: edgeSwipeHandler
        target: null
        yAxis.enabled: false
        onActiveChanged: {
            if (!active && centroid.pressPosition.x < 24 && centroid.position.x - centroid.pressPosition.x > 80) {
                root.StackView.view.pop();
            }
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.loading
        visible: running
    }

    Label {
        anchors.centerIn: parent
        anchors.margins: 16
        width: parent.width - 32
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        visible: root.errorMessage !== ""
        text: root.errorMessage
    }

    function _onArticleReceived(articleId, title, html) {
        if (articleId !== root.articleId)
            return;
        root.loading = false;
        webView.url = "data:text/html;charset=utf-8," + encodeURIComponent(html);
    }

    function _onArticleFailed(articleId, errorString) {
        if (articleId !== root.articleId)
            return;
        root.loading = false;
        root.errorMessage = qsTr("Failed to load article: ") + errorString;
    }

    Component.onCompleted: {
        if (root.articleId > 0) {
            eventsApiClient.articleReceived.connect(root._onArticleReceived);
            eventsApiClient.articleFetchFailed.connect(root._onArticleFailed);
            root.loading = true;
            eventsApiClient.fetchArticle(root.serverBaseUrl, root.articleId);
        } else {
            webView.url = root.pageUrl;
        }
    }

    Component.onDestruction: {
        eventsApiClient.articleReceived.disconnect(root._onArticleReceived);
        eventsApiClient.articleFetchFailed.disconnect(root._onArticleFailed);
    }
}
