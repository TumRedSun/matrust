// LoginPage.qml — token-based auto-login + password + manual token entry.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    color: Theme.window_bg

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacing_lg
        width: Math.min(440, parent.width - 32)

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/assets/logo.svg"
            sourceSize: Qt.size(72, 72)
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Sign in to Matrix")
            font.pixelSize: Theme.font_size_xl
            color: Theme.window_fg
        }

        TabBar {
            id: loginTabs
            Layout.fillWidth: true
            background: Rectangle { color: "transparent" }
            TabButton {
                text: qsTr("Password")
                checked: true
            }
            TabButton { text: qsTr("Token") }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: loginTabs.currentIndex

            // Password form
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing_sm

                TextField {
                    id: homeserverField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Homeserver (https://matrix.org)")
                    text: "https://matrix.org"
                    color: Theme.window_fg
                    background: Rectangle {
                        color: Theme.sidebar_bg
                        radius: Theme.radius_sm
                        border.color: Theme.border
                        border.width: 1
                    }
                }
                TextField {
                    id: usernameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Username")
                    color: Theme.window_fg
                    background: Rectangle {
                        color: Theme.sidebar_bg; radius: Theme.radius_sm
                        border.color: Theme.border; border.width: 1
                    }
                }
                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                    color: Theme.window_fg
                    background: Rectangle {
                        color: Theme.sidebar_bg; radius: Theme.radius_sm
                        border.color: Theme.border; border.width: 1
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    CheckBox {
                        id: ipv6Box
                        text: qsTr("Force IPv6 (only AAAA records)")
                        checked: false
                        contentItem: Label {
                            text: parent.parent.text
                            color: Theme.window_fg
                            leftPadding: parent.indicator.width + parent.spacing
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: qsTr("Sign in")
                        enabled: !MatrixClient.busy
                        background: Rectangle {
                            color: parent.enabled ? Theme.accent : Theme.muted
                            radius: Theme.radius_sm
                        }
                        contentItem: Label {
                            text: parent.text
                            color: Theme.accent_fg
                        }
                        onClicked: MatrixClient.loginWithPassword(
                            homeserverField.text, usernameField.text,
                            passwordField.text, ipv6Box.checked)
                    }
                }
            }

            // Token form
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing_sm

                Label {
                    text: qsTr("Auto-login via stored token. Paste the same access token your other client uses — no password is sent.")
                    color: Theme.muted
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    font.pixelSize: Theme.font_size_sm
                }

                TextField {
                    id: tokHs
                    Layout.fillWidth: true
                    placeholderText: qsTr("Homeserver URL")
                    text: "https://matrix.org"
                    color: Theme.window_fg
                    background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                }
                TextField {
                    id: tokUser
                    Layout.fillWidth: true
                    placeholderText: qsTr("User ID (@you:server)")
                    color: Theme.window_fg
                    background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                }
                TextField {
                    id: tokDevice
                    Layout.fillWidth: true
                    placeholderText: qsTr("Device ID (optional)")
                    color: Theme.window_fg
                    background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                }
                TextField {
                    id: tokToken
                    Layout.fillWidth: true
                    placeholderText: qsTr("Access token (syt_… / MDA… etc.)")
                    echoMode: TextInput.Password
                    color: Theme.window_fg
                    background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    CheckBox {
                        id: tokIpv6
                        text: qsTr("Force IPv6")
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: qsTr("Sign in")
                        enabled: !MatrixClient.busy
                        background: Rectangle { color: parent.enabled ? Theme.accent : Theme.muted; radius: Theme.radius_sm }
                        contentItem: Label { text: parent.text; color: Theme.accent_fg }
                        onClicked: MatrixClient.loginWithToken(
                            tokHs.text, tokUser.text, tokDevice.text, tokToken.text, tokIpv6.checked)
                    }
                }
            }
        }

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: MatrixClient.busy
            running: MatrixClient.busy
        }
    }
}
