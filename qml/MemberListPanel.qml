// MemberListPanel.qml — right sidebar: space info + member list with status/avatars.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    id: memberPanel
    color: Qt.darker(Theme.sidebarBg, 1.08)
    property string spaceId: ""
    property string spaceName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Space banner / name ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.bannerH - Theme.paddingLg
            color: Theme.accent
            opacity: 0.15
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.paddingMd
                spacing: 2

                Label {
                    id: spaceNameLabel
                    Layout.fillWidth: true
                    text: memberPanel.spaceName.length > 0 ? memberPanel.spaceName : memberPanel.spaceId
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    text: Tr.tr(Theme.language, "%1 members").arg(MemberModel.count)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // ── Member search ──
        TextField {
            id: memberSearch
            Layout.fillWidth: true
            Layout.leftMargin: Theme.paddingSm
            Layout.rightMargin: Theme.paddingSm
            Layout.topMargin: Theme.spacingSm
            Layout.bottomMargin: Theme.spacingSm
            placeholderText: Tr.tr(Theme.language, "Search members\u2026")
            color: Theme.sidebarFg
            font.pixelSize: Theme.fontSizeSm
            background: Rectangle {
                color: Theme.sidebarBg
                radius: Theme.radiusSm
                border.color: Theme.border
                border.width: 1
            }
        }

        // ── Member list ──
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: memberList
                model: MemberModel
                spacing: 0

                delegate: Item {
                    width: ListView.view.width

                    // Filter by search text
                    property bool matchesSearch: memberSearch.text.length === 0
                        || model.display_name.toLowerCase().indexOf(memberSearch.text.toLowerCase()) >= 0
                        || model.user_id.toLowerCase().indexOf(memberSearch.text.toLowerCase()) >= 0
                    visible: matchesSearch
                    height: matchesSearch ? Theme.headerH : 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.paddingSm
                        anchors.rightMargin: Theme.paddingSm
                        spacing: Theme.spacingSm

                        // Avatar
                        Rectangle {
                            Layout.preferredWidth: Theme.avatarListMd
                            Layout.preferredHeight: Theme.avatarListMd
                            radius: Theme.avatarListMd / 2
                            color: Theme.accent
                            opacity: 0.3

                            // Presence indicator
                            Rectangle {
                                visible: model.presence.length > 0
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: 10; height: 10
                                radius: 5
                                color: model.presence === "online" ? Theme.success
                                       : model.presence === "unavailable" ? Theme.warning
                                       : Theme.muted
                                border.color: Theme.sidebarBg
                                border.width: 2
                                z: 1
                            }

                            Label {
                                anchors.centerIn: parent
                                text: model.display_name.length > 0 ? model.display_name.charAt(0).toUpperCase() : "?"
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
                                text: model.display_name.length > 0 ? model.display_name : model.user_id
                                color: Theme.sidebarFg
                                font.pixelSize: Theme.fontSizeSm
                                elide: Text.ElideRight
                                // Show admin/mod badge
                                font.bold: model.power_level > 0
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                // Role badge
                                Rectangle {
                                    visible: model.power_level >= 100
                                    width: adminLbl.implicitWidth + 6
                                    height: 16
                                    radius: 3
                                    color: Theme.danger
                                    opacity: 0.7
                                    Label {
                                        id: adminLbl
                                        anchors.centerIn: parent
                                        text: Tr.tr(Theme.language, "Admin")
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSizeXs - 1
                                    }
                                }
                                Rectangle {
                                    visible: model.power_level > 0 && model.power_level < 100
                                    width: modLbl.implicitWidth + 6
                                    height: 16
                                    radius: 3
                                    color: Theme.accent
                                    opacity: 0.5
                                    Label {
                                        id: modLbl
                                        anchors.centerIn: parent
                                        text: Tr.tr(Theme.language, "Mod")
                                        color: Theme.accentFg
                                        font.pixelSize: Theme.fontSizeXs - 1
                                    }
                                }

                                // Status message
                                Label {
                                    Layout.fillWidth: true
                                    text: model.status_msg
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                    visible: model.status_msg.length > 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Load members when spaceId changes
    onSpaceIdChanged: {
        if (spaceId.length > 0) {
            MatrixClient.loadRoomMembers(spaceId)
        }
    }
}
