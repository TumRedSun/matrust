// LoginPage.qml — password login with auto-login via saved token.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.windowBg

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingLg
        width: Math.min(440, parent.width - 32)

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/assets/logo.svg"
            sourceSize: Qt.size(72, 72)
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr(Theme.language, "Sign in to Matrix")
            font.pixelSize: Theme.fontSizeXl
            color: Theme.windowFg
        }

        // Password form
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            TextField {
                id: homeserverField
                Layout.fillWidth: true
                placeholderText: Tr.tr(Theme.language, "Homeserver (https://matrix.org)")
                text: "https://matrix.org"
                color: Theme.windowFg
                background: Rectangle {
                    color: Theme.sidebarBg
                    radius: Theme.radiusSm
                    border.color: Theme.border
                    border.width: 1
                }
            }
            TextField {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: Tr.tr(Theme.language, "Username")
                color: Theme.windowFg
                background: Rectangle {
                    color: Theme.sidebarBg; radius: Theme.radiusSm
                    border.color: Theme.border; border.width: 1
                }
            }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: Tr.tr(Theme.language, "Password")
                echoMode: TextInput.Password
                color: Theme.windowFg
                background: Rectangle {
                    color: Theme.sidebarBg; radius: Theme.radiusSm
                    border.color: Theme.border; border.width: 1
                }
            }
            RowLayout {
                Layout.fillWidth: true
                CheckBox {
                    id: ipv6Box
                    text: Tr.tr(Theme.language, "Force IPv6 (only AAAA records)")
                    checked: false
                    contentItem: Label {
                        text: ipv6Box.text
                        color: Theme.windowFg
                        leftPadding: ipv6Box.indicator.width + ipv6Box.spacing
                    }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: Tr.tr(Theme.language, "Sign in")
                    enabled: !MatrixClient.busy
                    background: Rectangle {
                        color: parent.enabled ? Theme.accent : Theme.muted
                        radius: Theme.radiusSm
                    }
                    contentItem: Label {
                        text: parent.text
                        color: Theme.accentFg
                    }
                    onClicked: MatrixClient.loginWithPassword(
                        homeserverField.text, usernameField.text,
                        passwordField.text, ipv6Box.checked)
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr(Theme.language, "Your session will be saved for automatic login on next start.")
            color: Theme.muted
            font.pixelSize: Theme.fontSizeXs
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: MatrixClient.busy
            running: MatrixClient.busy
        }
    }
}
