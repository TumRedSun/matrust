// SettingsPage.qml — connection, IPv6, sync, logout, diagnostics.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.window_bg

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacing_md

            Label {
                Layout.leftMargin: Theme.padding_lg
                Layout.topMargin: Theme.padding_lg
                text: qsTr("Connection & Behavior")
                color: Theme.window_fg
                font.pixelSize: Theme.font_size_xl
                font.bold: true
            }

            // Account info
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg
                color: Theme.sidebar_bg
                radius: Theme.radius_md
                implicitHeight: accountCol.implicitHeight + Theme.padding_md * 2

                ColumnLayout {
                    id: accountCol
                    anchors.fill: parent
                    anchors.margins: Theme.padding_md
                    spacing: 4

                    Label { text: qsTr("Account"); color: Theme.accent; font.pixelSize: Theme.font_size_md; font.bold: true }
                    Label { text: qsTr("User ID: %1").arg(MatrixClient.userId); color: Theme.window_fg }
                    Label { text: qsTr("Status: %1").arg(MatrixClient.ready ? qsTr("Ready") : qsTr("Not connected")); color: Theme.window_fg }
                }
            }

            // Network
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg
                color: Theme.sidebar_bg
                radius: Theme.radius_md
                implicitHeight: netCol.implicitHeight + Theme.padding_md * 2

                ColumnLayout {
                    id: netCol
                    anchors.fill: parent
                    anchors.margins: Theme.padding_md
                    spacing: Theme.spacing_sm

                    Label { text: qsTr("Network"); color: Theme.accent; font.pixelSize: Theme.font_size_md; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Switch {
                            id: ipv6Switch
                            text: qsTr("Force IPv6-only transport")
                            checked: false
                            contentItem: Label {
                                text: ipv6Switch.text
                                color: Theme.window_fg
                                leftPadding: ipv6Switch.indicator.width + ipv6Switch.spacing
                            }
                            onToggled: MatrixClient.setForceIpv6(checked)
                        }
                        Label {
                            text: qsTr("(only AAAA records are resolved; IPv4 endpoints are refused)")
                            color: Theme.muted
                            font.pixelSize: Theme.font_size_xs
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // Diagnostics
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg
                color: Theme.sidebar_bg
                radius: Theme.radius_md
                implicitHeight: diagCol.implicitHeight + Theme.padding_md * 2

                ColumnLayout {
                    id: diagCol
                    anchors.fill: parent
                    anchors.margins: Theme.padding_md
                    spacing: Theme.spacing_sm

                    Label { text: qsTr("Diagnostics"); color: Theme.accent; font.pixelSize: Theme.font_size_md; font.bold: true }

                    Label {
                        text: qsTr("Last error: %1").arg(MatrixClient.lastError.length === 0 ? "—" : MatrixClient.lastError)
                        color: MatrixClient.lastError.length === 0 ? Theme.window_fg : Theme.danger
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
                            background: Rectangle { color: Theme.danger; radius: Theme.radius_sm }
                            contentItem: Label { text: parent.text; color: Theme.accent_fg }
                            onClicked: MatrixClient.logout()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: 64 }
        }
    }
}
