import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebView

// Renders "article"/"webcontent" events (project-description.md #2).
// Content is never fetched/stored by the server - this loads the live
// page directly, same as the Joomla importer's link-only strategy.
Page {
    id: root

    required property string pageUrl
    property string pageTitle: ""

    header: ToolBar {
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
        anchors.fill: parent
        url: root.pageUrl
    }
}
