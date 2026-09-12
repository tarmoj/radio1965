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
        anchors.fill: parent
        visible: !root.loading && root.errorMessage === ""
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
