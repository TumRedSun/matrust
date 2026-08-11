// SpacesPage.qml — left: spaces + rooms tree, right: chat preview.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    id: spacesRoot
    color: Theme.windowBg
    signal roomSelected(string roomId)
    property string activeRoomId: ""

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Spaces column ──
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 280
            color: Theme.sidebarBg

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.paddingMd
                    Layout.rightMargin: Theme.paddingMd
                    Layout.topMargin: Theme.paddingMd
                    Layout.bottomMargin: Theme.paddingSm
                    text: qsTr("Spaces & Rooms")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeLg
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
                                anchors.leftMargin: indent + Theme.paddingMd
                                anchors.rightMargin: Theme.paddingSm
                                spacing: Theme.spacingSm

                                Rectangle {
                                    Layout.preferredWidth: Theme.avatarSizeSm
                                    Layout.preferredHeight: Theme.avatarSizeSm
                                    radius: model.kind === "space" ? Theme.radiusSm
                                            : (Theme.avatarShape === "circle" ? Theme.avatarSizeSm/2
                                            : (Theme.avatarShape === "square" ? 0 : Theme.radiusSm))
                                    color: Theme.accent
                                    opacity: 0.3
                                    Label {
                                        anchors.centerIn: parent
                                        text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "#"
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSizeSm
                                        font.bold: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label {
                                        Layout.fillWidth: true
                                        text: model.name.length > 0 ? model.name : model.id
                                        color: Theme.sidebarFg
                                        font.pixelSize: Theme.fontSizeSm
                                        elide: Text.ElideRight
                                        font.bold: model.kind === "space"
                                    }
                                    Label {
                                        text: model.kind === "space" ? qsTr("space")
                                              : (model.is_direct ? qsTr("direct") : qsTr("room"))
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontSizeXs
                                        visible: model.unread === 0
                                    }
                                    Label {
                                        text: qsTr("%1 unread").arg(model.unread)
                                        color: model.highlight > 0 ? Theme.danger : Theme.accent
                                        font.pixelSize: Theme.fontSizeXs
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
                spacing: Theme.spacingMd

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Pick a room from the left to start chatting")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeLg
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
