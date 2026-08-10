// ProfilePage.qml — display name, avatar, presence.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    color: Theme.window_bg

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacing_lg
        width: Math.min(560, parent.width - 32)

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Your profile")
            color: Theme.window_fg
            font.pixelSize: Theme.font_size_xl
        }

        // Avatar with upload button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredSize: Theme.avatar_size_lg * 2
            radius: Theme.avatar_shape === "circle" ? (Theme.avatar_size_lg * 2) / 2
                    : (Theme.avatar_shape === "square" ? 0 : Theme.radius_lg)
            color: Theme.accent
            opacity: 0.3

            Label {
                anchors.centerIn: parent
                text: MatrixClient.userId.length > 0 ? MatrixClient.userId.charAt(1).toUpperCase() : "?"
                color: Theme.accent_fg
                font.pixelSize: Theme.font_size_xl * 2
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: avatarDialog.open()
            }
        }

        FileDialog {
            id: avatarDialog
            title: qsTr("Choose a new avatar")
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)"]
            onAccepted: {
                var p = avatarDialog.currentFile.toString()
                if (p.startsWith("file://")) p = p.substring(7)
                MatrixClient.setAvatar(p)
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: MatrixClient.profileManager().userId
            color: Theme.muted
            font.pixelSize: Theme.font_size_sm
        }

        // Display name editor
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing_sm
            Label { text: qsTr("Display name"); color: Theme.window_fg; Layout.preferredWidth: 120 }
            TextField {
                id: dnField
                Layout.fillWidth: true
                text: MatrixClient.profileManager().displayName
                color: Theme.window_fg
                background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
            }
            Button {
                text: qsTr("Save")
                background: Rectangle { color: Theme.accent; radius: Theme.radius_sm }
                contentItem: Label { text: parent.text; color: Theme.accent_fg }
                onClicked: MatrixClient.setDisplayName(dnField.text)
            }
        }

        // Presence
        Label { text: qsTr("Presence"); color: Theme.window_fg; font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing_sm
            ComboBox {
                id: presenceBox
                model: ["online", "unavailable", "offline"]
                Layout.preferredWidth: 180
            }
            TextField {
                id: statusField
                Layout.fillWidth: true
                placeholderText: qsTr("Status message (optional)")
                color: Theme.window_fg
                background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
            }
            Button {
                text: qsTr("Set")
                background: Rectangle { color: Theme.accent; radius: Theme.radius_sm }
                contentItem: Label { text: parent.text; color: Theme.accent_fg }
                onClicked: MatrixClient.profileManager().setPresence(presenceBox.currentText, statusField.text)
            }
        }

        Button {
            text: qsTr("Refresh profile")
            onClicked: MatrixClient.profileManager().refresh()
        }
    }

    Component.onCompleted: MatrixClient.profileManager().refresh()
}
