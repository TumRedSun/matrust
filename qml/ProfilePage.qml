// ProfilePage.qml — display name, avatar, presence, banner.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    color: Theme.windowBg

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.paddingMd
        spacing: Theme.spacingMd

        Label {
            text: Tr.tr(Theme.language, "Your profile")
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeXl
            font.bold: true
        }

        // Banner with upload
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.bannerH - Theme.paddingLg
            radius: Theme.radiusMd
            color: Theme.accent
            opacity: 0.15

            Label {
                anchors.centerIn: parent
                text: Tr.tr(Theme.language, "Click to set profile banner")
                color: Theme.sidebarFg
                font.pixelSize: Theme.fontSizeSm
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bannerDialog.open()
            }
        }

        FileDialog {
            id: bannerDialog
            title: Tr.tr(Theme.language, "Choose a banner image")
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)"]
            onAccepted: {
                // Banner upload via m.account_data — placeholder for future
            }
        }

        // Avatar with upload button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.avatarProfile
            Layout.preferredHeight: Theme.avatarProfile
            radius: Theme.avatarProfile / 2
            color: Theme.accent
            opacity: 0.3

            Label {
                anchors.centerIn: parent
                text: MatrixClient.userId.length > 0 ? MatrixClient.userId.charAt(1).toUpperCase() : "?"
                color: Theme.accentFg
                font.pixelSize: Theme.fontSizeXl * 2
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
            title: Tr.tr(Theme.language, "Choose a new avatar")
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg)"]
            onAccepted: {
                var p = avatarDialog.currentFile.toString()
                if (p.startsWith("file://")) p = p.substring(7)
                MatrixClient.setAvatar(p)
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: ProfileManager.userId
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSm
        }

        // Display name editor
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            Label { text: Tr.tr(Theme.language, "Name"); color: Theme.windowFg; Layout.preferredWidth: Theme.paddingLg * 2 + Theme.paddingMd }
            TextField {
                id: dnField
                Layout.fillWidth: true
                text: ProfileManager.displayName
                color: Theme.windowFg
                background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
            }
            Button {
                text: Tr.tr(Theme.language, "Save")
                background: Rectangle { color: Theme.accent; radius: Theme.radiusSm }
                contentItem: Label { text: parent.text; color: Theme.accentFg }
                onClicked: MatrixClient.setDisplayName(dnField.text)
            }
        }

        // Presence
        Label { text: Tr.tr(Theme.language, "Presence"); color: Theme.windowFg; font.bold: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            ComboBox {
                id: presenceBox
                model: ["online", "unavailable", "offline"]
                Layout.preferredWidth: Theme.comboBoxSmW
            }
            TextField {
                id: statusField
                Layout.fillWidth: true
                placeholderText: Tr.tr(Theme.language, "Status (optional)")
                color: Theme.windowFg
                background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
            }
            Button {
                text: Tr.tr(Theme.language, "Set")
                background: Rectangle { color: Theme.accent; radius: Theme.radiusSm }
                contentItem: Label { text: parent.text; color: Theme.accentFg }
                onClicked: ProfileManager.setPresence(presenceBox.currentText, statusField.text)
            }
        }

        Item { Layout.fillHeight: true }
    }

    Component.onCompleted: ProfileManager.refresh()
}
