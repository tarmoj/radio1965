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
    property string version: "0.2.2"
    title: qsTr("Radio 1965") + " v" + version
    color: Material.background

    property color backgroundEndColor: "darkgreen"


    Settings {
        id: appSettings
    }

    Component.onCompleted: {

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

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Label {
            text: qsTr("Content Area")
            font.pointSize: 14
            font.bold: true
        }

        Rectangle {
            id: contentRect
            color: "transparent"
            border.width: 1
            radius: 5
            border.color: Material.primaryColor.lighter()

            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 5
                clip: true

                ListView {
                    id: messageListView
                    width: parent.width
                    spacing: 8
                    model: notificationManager
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: messageListView.width
                        height: messageColumn.implicitHeight + 20
                        radius: 5
                        color: Material.backgroundColor.lighter()
                        border.width: 1
                        border.color: Material.primaryColor.lighter()

                        ColumnLayout {
                            id: messageColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            Label {
                                text: title
                                font.bold: true
                                font.pointSize: 13
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: summary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Label {
                                text: payload
                                font.pointSize: 10
                                font.italic: true
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

        }


    }


}
