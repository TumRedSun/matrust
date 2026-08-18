// SettingsOverlay.qml — Combined settings panel (profile, appearance, connection, language, account).
// Used as the content of the modal overlay in main.qml.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Item {
    id: settingsRoot
    signal closeSettings()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left: navigation tabs ──
        // Rounded only on its left edge (top-left + bottom-left) so it
        // follows the outer panel's rounded corners instead of painting
        // over them with a square edge.
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 180
            color: Theme.sidebarBg
            radius: Theme.radiusLg

            // Cover the right-side rounded corners so the sidebar meets
            // the content panel with a straight edge.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.radius
                color: parent.color
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.paddingSm
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.paddingSm
                    Layout.bottomMargin: Theme.paddingMd
                    text: Tr.tr(Theme.language, "Settings")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeXl
                    font.bold: true
                }

                // Tab buttons
                component TabButton: AbstractButton {
                    id: tabBtn
                    property bool isActive: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    hoverEnabled: true
                    background: Rectangle {
                        radius: Theme.radiusSm
                        color: tabBtn.isActive ? Theme.accent : (tabBtn.hovered ? Qt.lighter(Theme.sidebarBg, 1.15) : "transparent")
                        opacity: tabBtn.isActive ? 0.2 : 1.0
                    }
                    contentItem: Label {
                        text: tabBtn.text
                        color: tabBtn.isActive ? Theme.accentFg : Theme.sidebarFg
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: tabBtn.isActive
                        leftPadding: Theme.paddingSm
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                TabButton {
                    text: Tr.tr(Theme.language, "My Profile")
                    isActive: settingsStack.currentIndex === 0
                    onClicked: settingsStack.currentIndex = 0
                }
                TabButton {
                    text: Tr.tr(Theme.language, "Appearance")
                    isActive: settingsStack.currentIndex === 1
                    onClicked: settingsStack.currentIndex = 1
                }
                TabButton {
                    text: Tr.tr(Theme.language, "Connection")
                    isActive: settingsStack.currentIndex === 2
                    onClicked: settingsStack.currentIndex = 2
                }
                TabButton {
                    text: Tr.tr(Theme.language, "Language")
                    isActive: settingsStack.currentIndex === 3
                    onClicked: settingsStack.currentIndex = 3
                }

                Item { Layout.fillHeight: true }

                // Close button
                TabButton {
                    text: Tr.tr(Theme.language, "Close")
                    isActive: false
                    onClicked: settingsRoot.closeSettings()
                }
            }
        }

        // ── Right: settings content ──
        // Rounded only on its right edge (top-right + bottom-right) so it
        // follows the outer panel's rounded corners instead of painting
        // over them with a square edge.
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Theme.windowBg
            radius: Theme.radiusLg

            // Cover the left-side rounded corners so the content meets
            // the sidebar with a straight edge.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.radius
                color: parent.color
            }

            StackLayout {
                id: settingsStack
                anchors.fill: parent
                currentIndex: 0

                // ── Page 0: My Profile ──
                ScrollView {
                    clip: true
                    ColumnLayout {
                        width: parent.width - Theme.paddingLg * 2
                        x: Theme.paddingLg
                        spacing: Theme.spacingMd

                        Label {
                            Layout.topMargin: Theme.paddingMd
                            text: Tr.tr(Theme.language, "Your Profile")
                            color: Theme.windowFg
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        // Banner with upload
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            radius: Theme.radiusMd
                            color: Theme.accent
                            opacity: ProfileManager.bannerUrl.length > 0 ? 1.0 : 0.15
                            clip: true

                            // Banner image (only shown when a banner has been set).
                            // fillMode=PreserveAspectCrop gives a Discord-style cover.
                            Image {
                                anchors.fill: parent
                                source: ProfileManager.bannerUrl
                                fillMode: Image.PreserveAspectCrop
                                horizontalAlignment: Qt.AlignHCenter
                                verticalAlignment: Qt.AlignVCenter
                                visible: ProfileManager.bannerUrl.length > 0
                                asynchronous: true
                                cache: false  // always re-read the cached file
                            }

                            // Hint label only when there's no banner yet.
                            Label {
                                anchors.centerIn: parent
                                text: Tr.tr(Theme.language, "Click to set profile banner")
                                color: Theme.sidebarFg
                                font.pixelSize: Theme.fontSizeSm
                                visible: ProfileManager.bannerUrl.length === 0
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
                            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.svg *.bmp *.gif)"]
                            onAccepted: {
                                var p = bannerDialog.currentFile.toString()
                                if (p.startsWith("file://")) p = p.substring(7)
                                MatrixClient.setBanner(p)
                            }
                        }

                        // Avatar with upload button
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Theme.spacingMd

                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 80
                                radius: 40
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
                            Label { text: Tr.tr(Theme.language, "Name"); color: Theme.windowFg }
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
                                Layout.preferredWidth: 140
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

                        Item { Layout.fillHeight: true; Layout.preferredHeight: 32 }
                    }
                }

                // ── Page 1: Appearance ──
                ScrollView {
                    clip: true
                    ColumnLayout {
                        id: editor
                        width: parent.width - Theme.paddingLg * 2
                        x: Theme.paddingLg
                        spacing: Theme.spacingMd

                        Label {
                            Layout.topMargin: Theme.paddingMd
                            text: Tr.tr(Theme.language, "Appearance")
                            color: Theme.windowFg
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Label { text: Tr.tr(Theme.language, "Preset"); color: Theme.windowFg }
                            ComboBox {
                                id: presetCombo
                                model: JSON.parse(Theme.availablePresets())
                                Layout.preferredWidth: 180
                                onActivated: Theme.applyPreset(currentText)
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: Tr.tr(Theme.language, "Export")
                                onClicked: {
                                    exportDialog.text = Theme.exportJson()
                                    exportDialog.open()
                                }
                            }
                            Button {
                                text: Tr.tr(Theme.language, "Import")
                                onClicked: importDialog.open()
                            }
                            Button {
                                text: Tr.tr(Theme.language, "Reset")
                                onClicked: Theme.reset()
                            }
                        }

                        // ── Colors ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Colors")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                ColorRow { label: Tr.tr(Theme.language, "Window bg");    bind: "windowBg" }
                                ColorRow { label: Tr.tr(Theme.language, "Window fg");    bind: "windowFg" }
                                ColorRow { label: Tr.tr(Theme.language, "Sidebar bg");   bind: "sidebarBg" }
                                ColorRow { label: Tr.tr(Theme.language, "Sidebar fg");   bind: "sidebarFg" }
                                ColorRow { label: Tr.tr(Theme.language, "Accent");       bind: "accent" }
                                ColorRow { label: Tr.tr(Theme.language, "Accent fg");    bind: "accentFg" }
                                ColorRow { label: Tr.tr(Theme.language, "Danger");       bind: "danger" }
                                ColorRow { label: Tr.tr(Theme.language, "Success");      bind: "success" }
                                ColorRow { label: Tr.tr(Theme.language, "Warning");      bind: "warning" }
                                ColorRow { label: Tr.tr(Theme.language, "Muted");        bind: "muted" }
                                ColorRow { label: Tr.tr(Theme.language, "Border");       bind: "border" }
                                ColorRow { label: Tr.tr(Theme.language, "Bubble own bg");  bind: "bubbleBgMe" }
                                ColorRow { label: Tr.tr(Theme.language, "Bubble own fg");  bind: "bubbleFgMe" }
                                ColorRow { label: Tr.tr(Theme.language, "Bubble other bg"); bind: "bubbleBgThem" }
                                ColorRow { label: Tr.tr(Theme.language, "Bubble other fg"); bind: "bubbleFgThem" }
                            }
                        }

                        // ── Typography ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Typography")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                StringRow { label: Tr.tr(Theme.language, "Font family"); bind: "fontFamily" }
                                StringRow { label: Tr.tr(Theme.language, "Mono family");  bind: "fontFamilyMono" }
                                IntRow { label: Tr.tr(Theme.language, "Size XS"); bind: "fontSizeXs"; minValue: 6; maxValue: 32 }
                                IntRow { label: Tr.tr(Theme.language, "Size SM"); bind: "fontSizeSm"; minValue: 6; maxValue: 32 }
                                IntRow { label: Tr.tr(Theme.language, "Size MD"); bind: "fontSizeMd"; minValue: 6; maxValue: 32 }
                                IntRow { label: Tr.tr(Theme.language, "Size LG"); bind: "fontSizeLg"; minValue: 6; maxValue: 32 }
                                IntRow { label: Tr.tr(Theme.language, "Size XL"); bind: "fontSizeXl"; minValue: 6; maxValue: 64 }
                            }
                        }

                        // ── Geometry ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Geometry")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: Tr.tr(Theme.language, "Radius SM"); bind: "radiusSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Radius MD"); bind: "radiusMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Radius LG"); bind: "radiusLg"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Pad XS"); bind: "paddingXs"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Pad SM"); bind: "paddingSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Pad MD"); bind: "paddingMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Pad LG"); bind: "paddingLg"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Space XS"); bind: "spacingXs"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Space SM"); bind: "spacingSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Space MD"); bind: "spacingMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Space LG"); bind: "spacingLg"; minValue: 0; maxValue: 64 }
                            }
                        }

                        // ── Message bubbles ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Message bubbles")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: Tr.tr(Theme.language, "Bubble radius");    bind: "bubbleRadius";    minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Padding H");        bind: "bubblePaddingH";  minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Padding V");        bind: "bubblePaddingV";  minValue: 0; maxValue: 64 }
                                IntRow { label: Tr.tr(Theme.language, "Max width %");      bind: "bubbleMaxWidthPct"; minValue: 30; maxValue: 100 }

                                RowLayout {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    Switch {
                                        id: tailSwitch
                                        text: Tr.tr(Theme.language, "Bubble tail")
                                        checked: Theme.bubbleTail
                                        onToggled: Theme.bubbleTail = checked
                                    }
                                }
                            }
                        }

                        // ── Avatars ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Avatars")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: Tr.tr(Theme.language, "Size SM");  bind: "avatarSizeSm"; minValue: 16; maxValue: 96 }
                                IntRow { label: Tr.tr(Theme.language, "Size MD");  bind: "avatarSizeMd"; minValue: 16; maxValue: 128 }
                                IntRow { label: Tr.tr(Theme.language, "Size LG");  bind: "avatarSizeLg"; minValue: 16; maxValue: 256 }
                                IntRow { label: Tr.tr(Theme.language, "Corner r"); bind: "avatarRadius";  minValue: 0; maxValue: 128 }

                                RowLayout {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    Label { text: Tr.tr(Theme.language, "Shape"); color: Theme.windowFg }
                                    ComboBox {
                                        id: shapeCombo
                                        model: ["circle", "rounded", "square"]
                                        currentIndex: model.indexOf(Theme.avatarShape)
                                        onActivated: Theme.avatarShape = currentText
                                    }
                                }
                            }
                        }

                        // ── Behavior ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Behavior")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingSm

                                Switch { id: compactSwitch2; text: Tr.tr(Theme.language, "Compact mode"); checked: Theme.compactMode; onToggled: Theme.compactMode = checked }
                                Switch { id: tsSwitch2; text: Tr.tr(Theme.language, "Show timestamps"); checked: Theme.showTimestamps; onToggled: Theme.showTimestamps = checked }
                                Switch { id: avSwitch2; text: Tr.tr(Theme.language, "Show avatars"); checked: Theme.showAvatars; onToggled: Theme.showAvatars = checked }
                                Switch { id: animSwitch2; text: Tr.tr(Theme.language, "Animate bubbles"); checked: Theme.animateBubbles; onToggled: Theme.animateBubbles = checked }
                                IntRow { label: Tr.tr(Theme.language, "Anim ms"); bind: "animationDurationMs"; minValue: 0; maxValue: 1000 }
                            }
                        }

                        // ── Scrollbars ──
                        GroupBox {
                            title: Tr.tr(Theme.language, "Scrollbars")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd
                                IntRow { label: Tr.tr(Theme.language, "Width");  bind: "scrollbarSize";   minValue: 2; maxValue: 32 }
                                IntRow { label: Tr.tr(Theme.language, "Radius"); bind: "scrollbarRadius"; minValue: 0; maxValue: 16 }
                            }
                        }

                        Item { Layout.fillHeight: true; Layout.preferredHeight: 32 }
                    }
                }

                // ── Page 2: Connection ──
                ScrollView {
                    clip: true
                    ColumnLayout {
                        width: parent.width - Theme.paddingLg * 2
                        x: Theme.paddingLg
                        spacing: Theme.spacingMd

                        Label {
                            Layout.topMargin: Theme.paddingMd
                            text: Tr.tr(Theme.language, "Connection & Behavior")
                            color: Theme.windowFg
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        // Account info
                        Rectangle {
                            Layout.fillWidth: true
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

                        // Network
                        // IPv6-only toggle removed: the client now uses
                        // the default resolver which tries both A and AAAA
                        // records (happy-eyeballs). Homeservers can be
                        // specified by domain, IPv4, or [IPv6] in the
                        // login form.
                        Rectangle {
                            Layout.fillWidth: true
                            color: Theme.sidebarBg
                            radius: Theme.radiusMd
                            implicitHeight: netCol.implicitHeight + Theme.paddingMd * 2

                            ColumnLayout {
                                id: netCol
                                anchors.fill: parent
                                anchors.margins: Theme.paddingMd
                                spacing: Theme.spacingSm

                                Label { text: Tr.tr(Theme.language, "Network"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                                Label {
                                    text: Tr.tr(Theme.language, "Homeserver accepts domain, IPv4, or [IPv6] (port optional). Both A and AAAA records are tried.")
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // Diagnostics
                        Rectangle {
                            Layout.fillWidth: true
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

                                Button {
                                    text: Tr.tr(Theme.language, "Refresh rooms & spaces")
                                    onClicked: MatrixClient.refreshRooms()
                                }
                            }
                        }

                        // ── Account actions ──
                        Rectangle {
                            Layout.fillWidth: true
                            color: Theme.sidebarBg
                            radius: Theme.radiusMd
                            implicitHeight: actionCol.implicitHeight + Theme.paddingMd * 2

                            ColumnLayout {
                                id: actionCol
                                anchors.fill: parent
                                anchors.margins: Theme.paddingMd
                                spacing: Theme.spacingSm

                                Label { text: Tr.tr(Theme.language, "Account Actions"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm

                                    Button {
                                        text: Tr.tr(Theme.language, "Logout")
                                        background: Rectangle { color: Theme.warning; radius: Theme.radiusSm }
                                        contentItem: Label { text: parent.text; color: Theme.accentFg }
                                        onClicked: {
                                            MatrixClient.logout()
                                            settingsRoot.closeSettings()
                                        }
                                    }

                                    Button {
                                        text: Tr.tr(Theme.language, "Delete Account")
                                        background: Rectangle { color: Theme.danger; radius: Theme.radiusSm }
                                        contentItem: Label { text: parent.text; color: Theme.accentFg }
                                        onClicked: deleteConfirm.open()
                                    }
                                }

                                Label {
                                    text: Tr.tr(Theme.language, "Warning: Deleting your account is irreversible. All data will be permanently removed from the server.")
                                    color: Theme.danger
                                    font.pixelSize: Theme.fontSizeXs
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    visible: false
                                }
                            }
                        }

                        Item { Layout.fillHeight: true; Layout.preferredHeight: 64 }
                    }
                }

                // ── Page 3: Language ──
                ScrollView {
                    clip: true
                    ColumnLayout {
                        width: parent.width - Theme.paddingLg * 2
                        x: Theme.paddingLg
                        spacing: Theme.spacingMd

                        Label {
                            Layout.topMargin: Theme.paddingMd
                            text: Tr.tr(Theme.language, "Language")
                            color: Theme.windowFg
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            color: Theme.sidebarBg
                            radius: Theme.radiusMd
                            implicitHeight: langCol.implicitHeight + Theme.paddingMd * 2

                            ColumnLayout {
                                id: langCol
                                anchors.fill: parent
                                anchors.margins: Theme.paddingMd
                                spacing: Theme.spacingSm

                                Label { text: Tr.tr(Theme.language, "Interface Language"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm

                                    Label {
                                        text: Tr.tr(Theme.language, "Language")
                                        color: Theme.windowFg
                                    }

                                    ComboBox {
                                        id: langCombo
                                        model: JSON.parse(Theme.availableLanguages())
                                        currentIndex: {
                                            var langs = JSON.parse(Theme.availableLanguages())
                                            var idx = langs.indexOf(Theme.language)
                                            return idx >= 0 ? idx : 0
                                        }
                                        onActivated: Theme.language = currentText
                                    }
                                }

                                Label {
                                    text: Tr.tr(Theme.language, "Language changes apply immediately — no restart needed.")
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Language map (display names)
                        Rectangle {
                            Layout.fillWidth: true
                            color: Theme.sidebarBg
                            radius: Theme.radiusMd
                            implicitHeight: mapCol.implicitHeight + Theme.paddingMd * 2

                            ColumnLayout {
                                id: mapCol
                                anchors.fill: parent
                                anchors.margins: Theme.paddingMd
                                spacing: 4

                                Label { text: Tr.tr(Theme.language, "Available Languages"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                                GridLayout {
                                    columns: 3
                                    rowSpacing: 4
                                    columnSpacing: Theme.spacingSm
                                    Layout.fillWidth: true

                                    component LangLabel: Label {
                                        property string code
                                        text: {
                                            switch(code) {
                                                case "en": return "English"
                                                case "ru": return "\u0420\u0443\u0441\u0441\u043A\u0438\u0439"
                                                case "de": return "Deutsch"
                                                case "fr": return "Fran\u00E7ais"
                                                case "es": return "Espa\u00F1ol"
                                                case "pt": return "Portugu\u00EAs"
                                                case "ja": return "\u65E5\u672C\u8A9E"
                                                case "zh": return "\u4E2D\u6587"
                                                case "ko": return "\uD55C\uAD6D\uC5B4"
                                                case "it": return "Italiano"
                                                case "pl": return "Polski"
                                                case "uk": return "\u0423\u043A\u0440\u0430\u0457\u043D\u0441\u044C\u043A\u0430"
                                                default: return code
                                            }
                                        }
                                        color: Theme.windowFg
                                        font.pixelSize: Theme.fontSizeSm
                                    }

                                    LangLabel { code: "en" }
                                    LangLabel { code: "ru" }
                                    LangLabel { code: "de" }
                                    LangLabel { code: "fr" }
                                    LangLabel { code: "es" }
                                    LangLabel { code: "pt" }
                                    LangLabel { code: "ja" }
                                    LangLabel { code: "zh" }
                                    LangLabel { code: "ko" }
                                    LangLabel { code: "it" }
                                    LangLabel { code: "pl" }
                                    LangLabel { code: "uk" }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true; Layout.preferredHeight: 64 }
                    }
                }
            }
        }
    }

    // ─── Delete account confirmation dialog ───
    Dialog {
        id: deleteConfirm
        title: Tr.tr(Theme.language, "Delete Account")
        modal: true
        width: 360
        standardButtons: Dialog.Yes | Dialog.No
        contentItem: ColumnLayout {
            spacing: Theme.spacingSm
            Label {
                text: Tr.tr(Theme.language, "Are you sure you want to delete your account? This action is IRREVERSIBLE.")
                color: Theme.danger
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                text: Tr.tr(Theme.language, "All your data will be permanently removed from the server.")
                color: Theme.windowFg
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        onAccepted: {
            MatrixClient.deleteAccount()
            settingsRoot.closeSettings()
        }
    }

    // ─── Inline components (shared with AppearancePage) ───

    component ColorRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        // Label takes its natural implicit width (no fixed preferredWidth)
        // so translated labels (which can be much longer than English,
        // e.g. "Bubble own bg" → "Свой пузырь фон") don't get clipped or
        // cause the TextField to shrink. The GridLayout column auto-sizes
        // to the widest label, so labels still align across rows.
        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            radius: 4
            color: Theme[bind]
            border.color: Theme.border; border.width: 1
        }

        TextField {
            id: hexField
            Layout.fillWidth: true
            Layout.minimumWidth: 80
            text: Theme[bind]
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeSm
            onEditingFinished: {
                var v = text.trim()
                if (/^#[0-9a-fA-F]{3,8}$/.test(v)) {
                    Theme[bind] = v
                } else {
                    text = Theme[bind]
                }
            }
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
        }

        Button {
            text: "\uD83C\uDFA8"  // 🎨
            font.pixelSize: Theme.fontSizeSm
            onClicked: {
                picker.targetBind = bind
                picker.selectedColor = Theme[bind]
                picker.open()
            }
        }
    }

    component StringRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }
        TextField {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            text: Theme[bind]
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeSm
            onEditingFinished: Theme[bind] = text
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
        }
    }

    // Integer row: label + SpinBox + live preview.
    //
    // The preview is a small box that visually demonstrates what the
    // current value looks like. For radius/padding/size/etc. it shows a
    // Rectangle styled with that value, so the user can see the effect
    // without scanning a long slider. No more −/+ buttons or sliders —
    // just type a number (or use the SpinBox arrows) and watch the
    // preview update.
    component IntRow: RowLayout {
        property string label
        property string bind
        property int minValue: 0
        property int maxValue: 100
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }

        // SpinBox: editable number input with up/down arrows.
        // `value` is bound to Theme[bind] both ways — editing the value
        // updates the theme, and external theme changes (e.g. applying a
        // preset) reflect in the SpinBox.
        SpinBox {
            id: spin
            Layout.preferredWidth: 100
            from: minValue
            to: maxValue
            value: Theme[bind]
            onValueModified: Theme[bind] = value
            editable: true
            font.pixelSize: Theme.fontSizeSm
        }

        // Live preview — adapts to the property being edited.
        Rectangle {
            id: previewBox
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.sidebarBg
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            // The actual preview element — chosen based on the bind name.
            // We use simple substring matching on the bind name to pick
            // the right visualization. This keeps the component generic
            // instead of needing a separate row type for each property.
            Item {
                anchors.fill: parent
                anchors.margins: 4

                // Radius preview: a rectangle with that corner radius.
                Rectangle {
                    visible: bind.indexOf("adius") >= 0 || bind === "avatarRadius" || bind === "scrollbarRadius"
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: Math.min(Theme[bind], 24)
                    color: Theme.accent
                }

                // Padding preview: inner box inset by half the padding value.
                Rectangle {
                    visible: bind.indexOf("adding") >= 0
                    anchors.fill: parent
                    color: "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Math.min(Theme[bind], parent.width / 2)
                        height: parent.height - Math.min(Theme[bind], parent.height / 2)
                        color: Theme.accent
                        opacity: 0.5
                    }
                }

                // Spacing preview: two dots separated by the spacing value.
                Item {
                    visible: bind.indexOf("pacing") >= 0
                    anchors.fill: parent
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        width: 8; height: 8; radius: 4; color: Theme.accent
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Math.min(8 + Theme[bind], parent.width - 8)
                        width: 8; height: 8; radius: 4; color: Theme.accent
                    }
                }

                // Font size preview: shows "Aa" at that font size.
                Text {
                    visible: bind.indexOf("ontSize") >= 0 || bind.indexOf("imationDuration") >= 0
                    anchors.centerIn: parent
                    text: "Aa"
                    color: Theme.windowFg
                    font.pixelSize: Math.min(Theme[bind], 28)
                }

                // Size preview (avatarSize*): a circle/box of that size
                // (capped to fit the preview box).
                Rectangle {
                    visible: bind.indexOf("avatarSize") >= 0 || bind.indexOf("crollbarSize") >= 0
                    anchors.centerIn: parent
                    width: Math.min(Theme[bind], parent.width)
                    height: bind.indexOf("crollbarSize") >= 0 ? Math.min(Theme[bind], parent.height) : Math.min(Theme[bind], parent.width)
                    radius: bind === "avatarSizeSm" || bind === "avatarSizeMd" || bind === "avatarSizeLg" ? width / 2 : 2
                    color: Theme.accent
                    opacity: 0.6
                }

                // Bubble max width % preview: a horizontal bar fill.
                Rectangle {
                    visible: bind.indexOf("axWidth") >= 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Theme[bind] / 100
                    height: 8
                    color: Theme.accent
                    radius: 2
                }

                // Width preview (scrollbarSize): handled above by Size branch.
            }
        }
    }

    ColorDialog {
        id: picker
        property string targetBind: ""
        onAccepted: {
            Theme[targetBind] = picker.selectedColor.toString()
        }
    }

    Dialog {
        id: exportDialog
        title: Tr.tr(Theme.language, "Theme JSON")
        modal: true
        anchors.centerIn: parent
        width: 500
        property string text: ""
        contentItem: ScrollView {
            TextArea {
                text: exportDialog.text
                readOnly: true
                wrapMode: TextArea.Wrap
                color: Theme.windowFg
                background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm }
            }
        }
        standardButtons: Dialog.Close
    }

    Dialog {
        id: importDialog
        title: Tr.tr(Theme.language, "Paste theme JSON")
        modal: true
        anchors.centerIn: parent
        width: 500
        contentItem: TextArea {
            id: importField
            wrapMode: TextArea.Wrap
            color: Theme.windowFg
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (!Theme.importJson(importField.text)) {
                ApplicationWindow.window.showToast(Tr.tr(Theme.language, "Invalid JSON"))
            }
            importField.text = ""
        }
    }

    Component.onCompleted: ProfileManager.refresh()
}
