// SettingsPage.qml — connection, IPv6, sync, logout, diagnostics.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.windowBg

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacingMd

            Label {
                Layout.leftMargin: Theme.paddingLg
                Layout.topMargin: Theme.paddingLg
                text: qsTr("Connection & Behavior")
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
            }

            // Account info
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg
                color: Theme.sidebarBg
                radius: Theme.radiusMd
                implicitHeight: accountCol.implicitHeight + Theme.paddingMd * 2

                ColumnLayout {
                    id: accountCol
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMd
                    spacing: 4

                    Label { text: qsTr("Account"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                    Label { text: qsTr("User ID: %1").arg(MatrixClient.userId); color: Theme.windowFg }
                    Label { text: qsTr("Status: %1").arg(MatrixClient.ready ? qsTr("Ready") : qsTr("Not connected")); color: Theme.windowFg }
                }
            }

            // Network
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg
                color: Theme.sidebarBg
                radius: Theme.radiusMd
                implicitHeight: netCol.implicitHeight + Theme.paddingMd * 2

                ColumnLayout {
                    id: netCol
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMd
                    spacing: Theme.spacingSm

                    Label { text: qsTr("Network"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Switch {
                            id: ipv6Switch
                            text: qsTr("Force IPv6-only transport")
                            checked: false
                            contentItem: Label {
                                text: ipv6Switch.text
                                color: Theme.windowFg
                                leftPadding: ipv6Switch.indicator.width + ipv6Switch.spacing
                            }
                            onToggled: MatrixClient.setForceIpv6(checked)
                        }
                        Label {
                            text: qsTr("(only AAAA records are resolved; IPv4 endpoints are refused)")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeXs
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // Diagnostics
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg
                color: Theme.sidebarBg
                radius: Theme.radiusMd
                implicitHeight: diagCol.implicitHeight + Theme.paddingMd * 2

                ColumnLayout {
                    id: diagCol
                    anchors.fill: parent
                    anchors.margins: Theme.paddingMd
                    spacing: Theme.spacingSm

                    Label { text: qsTr("Diagnostics"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                    Label {
                        text: qsTr("Last error: %1").arg(MatrixClient.lastError.length === 0 ? "—" : MatrixClient.lastError)
                        color: MatrixClient.lastError.length === 0 ? Theme.windowFg : Theme.danger
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: qsTr("Refresh rooms & spaces")
                            onClicked: MatrixClient.refreshRooms()
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: qsTr("Logout")
                            background: Rectangle { color: Theme.danger; radius: Theme.radiusSm }
                            contentItem: Label { text: parent.text; color: Theme.accentFg }
                            onClicked: MatrixClient.logout()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: 64 }
        }
    }
}
