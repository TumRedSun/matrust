// RoomsSidebar.qml — flat list of joined rooms (alternative to Spaces view).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.sidebar_bg
    signal roomSelected(string roomId)
    property string activeRoomId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding_md
            Layout.topMargin: Theme.padding_md
            Layout.bottomMargin: Theme.padding_sm
            text: qsTr("Direct messages & Rooms")
            color: Theme.sidebar_fg
            font.pixelSize: Theme.font_size_lg
            font.bold: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: MatrixClient.roomModel()
                spacing: 0
                delegate: Item {
                    width: ListView.view.width
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        color: activeRoomId === model.room_id ? Theme.accent : "transparent"
                        opacity: activeRoomId === model.room_id ? 0.18 : 0
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padding_md
                        anchors.rightMargin: Theme.padding_sm
                        spacing: Theme.spacing_sm

                        Rectangle {
                            Layout.preferredWidth: Theme.avatar_size_md
                            Layout.preferredHeight: Theme.avatar_size_md
                            radius: Theme.avatar_shape === "circle" ? Theme.avatar_size_md/2 : (Theme.avatar_shape === "square" ? 0 : Theme.avatar_radius)
                            color: Theme.accent
                            opacity: 0.3
                            Label {
                                anchors.centerIn: parent
                                text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "?"
                                color: Theme.accent_fg
                                font.pixelSize: Theme.font_size_md
                                font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: model.name.length > 0 ? model.name : model.room_id
                                color: Theme.sidebar_fg
                                elide: Text.ElideRight
                                font.pixelSize: Theme.font_size_sm
                                font.bold: model.has_unread
                            }
                            Label {
                                Layout.fillWidth: true
                                text: model.last_event
                                color: Theme.muted
                                elide: Text.ElideRight
                                font.pixelSize: Theme.font_size_xs
                                visible: !model.has_unread
                            }
                        }
                        Rectangle {
                            visible: model.unread_count > 0
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: model.highlight_count > 0 ? Theme.danger : Theme.accent
                            Label {
                                anchors.centerIn: parent
                                text: model.unread_count
                                color: Theme.accent_fg
                                font.pixelSize: Theme.font_size_xs
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
