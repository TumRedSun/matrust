// SpacesPage.qml — left: spaces + rooms tree, right: chat preview.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    id: spacesRoot
    color: Theme.window_bg
    signal roomSelected(string roomId)
    property string activeRoomId: ""

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Spaces column ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            color: Theme.sidebar_bg

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padding_md
                    Layout.rightMargin: Theme.padding_md
                    Layout.topMargin: Theme.padding_md
                    Layout.bottomMargin: Theme.padding_sm
                    text: qsTr("Spaces & Rooms")
                    color: Theme.sidebar_fg
                    font.pixelSize: Theme.font_size_lg
                    font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: tree
                        model: MatrixClient.spaceModel()
                        spacing: 0

                        delegate: Item {
                            width: ListView.view.width
                            height: 48
                            property int indent: model.parent_id.length > 0 ? 24 : 0

                            Rectangle {
                                anchors.fill: parent
                                color: spacesRoot.activeRoomId === model.id ? Theme.accent : "transparent"
                                opacity: spacesRoot.activeRoomId === model.id ? 0.18 : 0
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: indent + Theme.padding_md
                                anchors.rightMargin: Theme.padding_sm
                                spacing: Theme.spacing_sm

                                Rectangle {
                                    Layout.preferredWidth: Theme.avatar_size_sm
                                    Layout.preferredHeight: Theme.avatar_size_sm
                                    radius: model.kind === "space" ? Theme.radius_sm
                                            : (Theme.avatar_shape === "circle" ? Theme.avatar_size_sm/2
                                            : (Theme.avatar_shape === "square" ? 0 : Theme.radius_sm))
                                    color: Theme.accent
                                    opacity: 0.3
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "#"
                                        color: Theme.accent_fg
                                        font.pixelSize: Theme.font_size_sm
                                        font.bold: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label {
                                        Layout.fillWidth: true
                                        text: model.name.length > 0 ? model.name : model.id
                                        color: Theme.sidebar_fg
                                        font.pixelSize: Theme.font_size_sm
                                        elide: Text.ElideRight
                                        font.bold: model.kind === "space"
                                    }
                                    Label {
                                        text: model.kind === "space" ? qsTr("space")
                                              : (model.is_direct ? qsTr("direct") : qsTr("room"))
                                        color: Theme.muted
                                        font.pixelSize: Theme.font_size_xs
                                        visible: model.unread === 0
                                    }
                                    Label {
                                        text: qsTr("%1 unread").arg(model.unread)
                                        color: model.highlight > 0 ? Theme.danger : Theme.accent
                                        font.pixelSize: Theme.font_size_xs
                                        visible: model.unread > 0
                                        font.bold: true
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.kind === "room") {
                                        spacesRoot.roomSelected(model.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Right pane: instructions / placeholder ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacing_md

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Pick a room from the left to start chatting")
                    color: Theme.muted
                    font.pixelSize: Theme.font_size_lg
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Refresh")
                    onClicked: MatrixClient.refreshRooms()
                }
            }
        }
    }

    Component.onCompleted: MatrixClient.refreshRooms()
}
