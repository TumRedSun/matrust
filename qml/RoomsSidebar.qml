// RoomsSidebar.qml — flat list of joined rooms (alternative to Spaces view).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.sidebarBg
    signal roomSelected(string roomId)
    property string activeRoomId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.paddingMd
            Layout.topMargin: Theme.paddingMd
            Layout.bottomMargin: Theme.paddingSm
            text: Tr.tr(Theme.language, "Direct messages & Rooms")
            color: Theme.sidebarFg
            font.pixelSize: Theme.fontSizeLg
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: RoomModel
                spacing: 0
                delegate: Item {
                    width: ListView.view.width
                    height: Theme.roomRowH

                    Rectangle {
                        anchors.fill: parent
                        color: activeRoomId === model.room_id ? Theme.accent : "transparent"
                        opacity: activeRoomId === model.room_id ? 0.18 : 0
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingMd
                        anchors.rightMargin: Theme.paddingSm
                        spacing: Theme.spacingSm

                        Rectangle {
                            Layout.preferredWidth: Theme.avatarSizeMd
                            Layout.preferredHeight: Theme.avatarSizeMd
                            radius: Theme.avatarShape === "circle" ? Theme.avatarSizeMd/2 : (Theme.avatarShape === "square" ? 0 : Theme.avatarRadius)
                            color: Theme.accent
                            opacity: 0.3
                            Label {
                                anchors.centerIn: parent
                                text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "?"
                                color: Theme.accentFg
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: model.name.length > 0 ? model.name : model.room_id
                                color: Theme.sidebarFg
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: model.has_unread
                            }
                            Label {
                                Layout.fillWidth: true
                                text: model.last_event
                                color: Theme.muted
                                elide: Text.ElideRight
                                font.pixelSize: Theme.fontSizeXs
                                visible: !model.has_unread
                            }
                        }
                        Rectangle {
                            visible: model.unread_count > 0
                            Layout.preferredWidth: Math.max(Theme.colorSwatchSize - 4, unreadLbl.implicitWidth + Theme.paddingXs)
                            Layout.preferredHeight: Theme.colorSwatchSize - 4
                            radius: (Theme.colorSwatchSize - 4) / 2
                            color: model.highlight_count > 0 ? Theme.danger : Theme.accent
                            Label {
                                id: unreadLbl
                                anchors.centerIn: parent
                                text: model.unread_count
                                color: Theme.accentFg
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: roomSelected(model.room_id)
                    }
                }
            }
        }
    }
}
