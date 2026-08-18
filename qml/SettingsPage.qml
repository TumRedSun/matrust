// SettingsPage.qml — connection, IPv6, sync, logout, diagnostics.
// Superseded by the settings inside SettingsOverlay.qml,
// but kept for backwards compatibility if loaded standalone.
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
                text: Tr.tr(Theme.language, "Connection & Behavior")
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
            }

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
                    Label { text: Tr.tr(Theme.language, "Account"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                    Label { text: Tr.tr(Theme.language, "User ID: %1").arg(MatrixClient.userId); color: Theme.windowFg }
                    Label { text: Tr.tr(Theme.language, "Status: %1").arg(MatrixClient.ready ? Tr.tr(Theme.language, "Ready") : Tr.tr(Theme.language, "Not connected")); color: Theme.windowFg }
                }
            }

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
                    Label { text: Tr.tr(Theme.language, "Network"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Switch {
                            id: ipv6Switch
                            text: Tr.tr(Theme.language, "Force IPv6-only transport")
                            checked: false
                            contentItem: Label {
                                text: ipv6Switch.text
                                color: Theme.windowFg
                                leftPadding: ipv6Switch.indicator.width + ipv6Switch.spacing
                            }
                            onToggled: MatrixClient.setForceIpv6(checked)
                        }
                        Label {
                            text: Tr.tr(Theme.language, "(only AAAA records are resolved; IPv4 endpoints are refused)")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeXs
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

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
                    Label { text: Tr.tr(Theme.language, "Diagnostics"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                    Label {
                        text: Tr.tr(Theme.language, "Last error: %1").arg(MatrixClient.lastError.length === 0 ? "\u2014" : MatrixClient.lastError)
                        color: MatrixClient.lastError.length === 0 ? Theme.windowFg : Theme.danger
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Button { text: Tr.tr(Theme.language, "Refresh rooms & spaces"); onClicked: MatrixClient.refreshRooms() }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: Tr.tr(Theme.language, "Logout")
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
