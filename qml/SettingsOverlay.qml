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
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 180
            color: Theme.sidebarBg

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.paddingSm
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.paddingSm
                    Layout.bottomMargin: Theme.paddingMd
                    text: qsTr("Settings")
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
                    text: qsTr("My Profile")
                    isActive: settingsStack.currentIndex === 0
                    onClicked: settingsStack.currentIndex = 0
                }
                TabButton {
                    text: qsTr("Appearance")
                    isActive: settingsStack.currentIndex === 1
                    onClicked: settingsStack.currentIndex = 1
                }
                TabButton {
                    text: qsTr("Connection")
                    isActive: settingsStack.currentIndex === 2
                    onClicked: settingsStack.currentIndex = 2
                }
                TabButton {
                    text: qsTr("Language")
                    isActive: settingsStack.currentIndex === 3
                    onClicked: settingsStack.currentIndex = 3
                }

                Item { Layout.fillHeight: true }

                // Close button
                TabButton {
                    text: qsTr("Close")
                    isActive: false
                    onClicked: settingsRoot.closeSettings()
                }
            }
        }

        // ── Right: settings content ──
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Theme.windowBg

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
                            text: qsTr("Your Profile")
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
                                text: qsTr("Click to set profile banner")
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
                            title: qsTr("Choose a banner image")
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
                            text: ProfileManager.userId
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSm
                        }

                        // Display name editor
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Label { text: qsTr("Name"); color: Theme.windowFg; Layout.preferredWidth: 80 }
                            TextField {
                                id: dnField
                                Layout.fillWidth: true
                                text: ProfileManager.displayName
                                color: Theme.windowFg
                                background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
                            }
                            Button {
                                text: qsTr("Save")
                                background: Rectangle { color: Theme.accent; radius: Theme.radiusSm }
                                contentItem: Label { text: parent.text; color: Theme.accentFg }
                                onClicked: MatrixClient.setDisplayName(dnField.text)
                            }
                        }

                        // Presence
                        Label { text: qsTr("Presence"); color: Theme.windowFg; font.bold: true }
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
                                placeholderText: qsTr("Status (optional)")
                                color: Theme.windowFg
                                background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
                            }
                            Button {
                                text: qsTr("Set")
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
                            text: qsTr("Appearance")
                            color: Theme.windowFg
                            font.pixelSize: Theme.fontSizeXl
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Label { text: qsTr("Preset"); color: Theme.windowFg; Layout.preferredWidth: 70 }
                            ComboBox {
                                id: presetCombo
                                model: JSON.parse(Theme.availablePresets())
                                Layout.preferredWidth: 180
                                onActivated: Theme.applyPreset(currentText)
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: qsTr("Export")
                                onClicked: {
                                    exportDialog.text = Theme.exportJson()
                                    exportDialog.open()
                                }
                            }
                            Button {
                                text: qsTr("Import")
                                onClicked: importDialog.open()
                            }
                            Button {
                                text: qsTr("Reset")
                                onClicked: Theme.reset()
                            }
                        }

                        // ── Colors ──
                        GroupBox {
                            title: qsTr("Colors")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                ColorRow { label: qsTr("Window bg");    bind: "windowBg" }
                                ColorRow { label: qsTr("Window fg");    bind: "windowFg" }
                                ColorRow { label: qsTr("Sidebar bg");   bind: "sidebarBg" }
                                ColorRow { label: qsTr("Sidebar fg");   bind: "sidebarFg" }
                                ColorRow { label: qsTr("Accent");       bind: "accent" }
                                ColorRow { label: qsTr("Accent fg");    bind: "accentFg" }
                                ColorRow { label: qsTr("Danger");       bind: "danger" }
                                ColorRow { label: qsTr("Success");      bind: "success" }
                                ColorRow { label: qsTr("Warning");      bind: "warning" }
                                ColorRow { label: qsTr("Muted");        bind: "muted" }
                                ColorRow { label: qsTr("Border");       bind: "border" }
                                ColorRow { label: qsTr("Bubble own bg");  bind: "bubbleBgMe" }
                                ColorRow { label: qsTr("Bubble own fg");  bind: "bubbleFgMe" }
                                ColorRow { label: qsTr("Bubble other bg"); bind: "bubbleBgThem" }
                                ColorRow { label: qsTr("Bubble other fg"); bind: "bubbleFgThem" }
                            }
                        }

                        // ── Typography ──
                        GroupBox {
                            title: qsTr("Typography")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                StringRow { label: qsTr("Font family"); bind: "fontFamily" }
                                StringRow { label: qsTr("Mono family");  bind: "fontFamilyMono" }
                                IntRow { label: qsTr("Size XS"); bind: "fontSizeXs"; minValue: 6; maxValue: 32 }
                                IntRow { label: qsTr("Size SM"); bind: "fontSizeSm"; minValue: 6; maxValue: 32 }
                                IntRow { label: qsTr("Size MD"); bind: "fontSizeMd"; minValue: 6; maxValue: 32 }
                                IntRow { label: qsTr("Size LG"); bind: "fontSizeLg"; minValue: 6; maxValue: 32 }
                                IntRow { label: qsTr("Size XL"); bind: "fontSizeXl"; minValue: 6; maxValue: 64 }
                            }
                        }

                        // ── Geometry ──
                        GroupBox {
                            title: qsTr("Geometry")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: qsTr("Radius SM"); bind: "radiusSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Radius MD"); bind: "radiusMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Radius LG"); bind: "radiusLg"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Pad XS"); bind: "paddingXs"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Pad SM"); bind: "paddingSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Pad MD"); bind: "paddingMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Pad LG"); bind: "paddingLg"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Space XS"); bind: "spacingXs"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Space SM"); bind: "spacingSm"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Space MD"); bind: "spacingMd"; minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Space LG"); bind: "spacingLg"; minValue: 0; maxValue: 64 }
                            }
                        }

                        // ── Message bubbles ──
                        GroupBox {
                            title: qsTr("Message bubbles")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: qsTr("Bubble radius");    bind: "bubbleRadius";    minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Padding H");        bind: "bubblePaddingH";  minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Padding V");        bind: "bubblePaddingV";  minValue: 0; maxValue: 64 }
                                IntRow { label: qsTr("Max width %");      bind: "bubbleMaxWidthPct"; minValue: 30; maxValue: 100 }

                                RowLayout {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    Switch {
                                        id: tailSwitch
                                        text: qsTr("Bubble tail")
                                        checked: Theme.bubbleTail
                                        onToggled: Theme.bubbleTail = checked
                                    }
                                }
                            }
                        }

                        // ── Avatars ──
                        GroupBox {
                            title: qsTr("Avatars")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd

                                IntRow { label: qsTr("Size SM");  bind: "avatarSizeSm"; minValue: 16; maxValue: 96 }
                                IntRow { label: qsTr("Size MD");  bind: "avatarSizeMd"; minValue: 16; maxValue: 128 }
                                IntRow { label: qsTr("Size LG");  bind: "avatarSizeLg"; minValue: 16; maxValue: 256 }
                                IntRow { label: qsTr("Corner r"); bind: "avatarRadius";  minValue: 0; maxValue: 128 }

                                RowLayout {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    Label { text: qsTr("Shape"); color: Theme.windowFg; Layout.preferredWidth: 80 }
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
                            title: qsTr("Behavior")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingSm

                                Switch { id: compactSwitch2; text: qsTr("Compact mode"); checked: Theme.compactMode; onToggled: Theme.compactMode = checked }
                                Switch { id: tsSwitch2; text: qsTr("Show timestamps"); checked: Theme.showTimestamps; onToggled: Theme.showTimestamps = checked }
                                Switch { id: avSwitch2; text: qsTr("Show avatars"); checked: Theme.showAvatars; onToggled: Theme.showAvatars = checked }
                                Switch { id: animSwitch2; text: qsTr("Animate bubbles"); checked: Theme.animateBubbles; onToggled: Theme.animateBubbles = checked }
                                IntRow { label: qsTr("Anim ms"); bind: "animationDurationMs"; minValue: 0; maxValue: 1000 }
                            }
                        }

                        // ── Scrollbars ──
                        GroupBox {
                            title: qsTr("Scrollbars")
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontSizeMd

                            GridLayout {
                                anchors.fill: parent
                                columns: 2
                                rowSpacing: Theme.spacingSm
                                columnSpacing: Theme.spacingMd
                                IntRow { label: qsTr("Width");  bind: "scrollbarSize";   minValue: 2; maxValue: 32 }
                                IntRow { label: qsTr("Radius"); bind: "scrollbarRadius"; minValue: 0; maxValue: 16 }
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
                            text: qsTr("Connection & Behavior")
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

                                Label { text: qsTr("Account"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }
                                Label { text: qsTr("User ID: %1").arg(MatrixClient.userId); color: Theme.windowFg }
                                Label { text: qsTr("Status: %1").arg(MatrixClient.ready ? qsTr("Ready") : qsTr("Not connected")); color: Theme.windowFg }
                            }
                        }

                        // Network
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
                                    text: qsTr("Last error: %1").arg(MatrixClient.lastError.length === 0 ? "\u2014" : MatrixClient.lastError)
                                    color: MatrixClient.lastError.length === 0 ? Theme.windowFg : Theme.danger
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: qsTr("Refresh rooms & spaces")
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

                                Label { text: qsTr("Account Actions"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm

                                    Button {
                                        text: qsTr("Logout")
                                        background: Rectangle { color: Theme.warning; radius: Theme.radiusSm }
                                        contentItem: Label { text: parent.text; color: Theme.accentFg }
                                        onClicked: {
                                            MatrixClient.logout()
                                            settingsRoot.closeSettings()
                                        }
                                    }

                                    Button {
                                        text: qsTr("Delete Account")
                                        background: Rectangle { color: Theme.danger; radius: Theme.radiusSm }
                                        contentItem: Label { text: parent.text; color: Theme.accentFg }
                                        onClicked: deleteConfirm.open()
                                    }
                                }

                                Label {
                                    text: qsTr("Warning: Deleting your account is irreversible. All data will be permanently removed from the server.")
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
                            text: qsTr("Language")
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

                                Label { text: qsTr("Interface Language"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingSm

                                    Label {
                                        text: qsTr("Language")
                                        color: Theme.windowFg
                                        Layout.preferredWidth: 80
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
                                    text: qsTr("Changing the language will take effect after restarting the application.")
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

                                Label { text: qsTr("Available Languages"); color: Theme.accent; font.pixelSize: Theme.fontSizeMd; font.bold: true }

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
        title: qsTr("Delete Account")
        modal: true
        width: 360
        standardButtons: Dialog.Yes | Dialog.No
        contentItem: ColumnLayout {
            spacing: Theme.spacingSm
            Label {
                text: qsTr("Are you sure you want to delete your account? This action is IRREVERSIBLE.")
                color: Theme.danger
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Label {
                text: qsTr("All your data will be permanently removed from the server.")
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

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 100; font.pixelSize: Theme.fontSizeSm }

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
            Layout.preferredWidth: 80
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
            text: qsTr("\uD83C\uDFA8")
            font.pixelSize: Theme.fontSizeSm
            onClicked: {
                picker.targetBind = bind
                picker.color = Theme[bind]
                picker.open()
            }
        }
    }

    component StringRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 100; font.pixelSize: Theme.fontSizeSm }
        TextField {
            Layout.fillWidth: true
            text: Theme[bind]
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeSm
            onEditingFinished: Theme[bind] = text
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
        }
    }

    component IntRow: RowLayout {
        property string label
        property string bind
        property int minValue: 0
        property int maxValue: 100
        Layout.fillWidth: true
        spacing: 4

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 100; font.pixelSize: Theme.fontSizeSm }

        Button {
            text: "\u2212"
            font.pixelSize: Theme.fontSizeSm
            enabled: Theme[bind] > minValue
            onClicked: Theme[bind] = Theme[bind] - 1
        }
        Label {
            Layout.preferredWidth: 36
            text: Theme[bind]
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeSm
            horizontalAlignment: Qt.AlignHCenter
        }
        Button {
            text: "+"
            font.pixelSize: Theme.fontSizeSm
            enabled: Theme[bind] < maxValue
            onClicked: Theme[bind] = Theme[bind] + 1
        }
        Slider {
            Layout.fillWidth: true
            from: minValue
            to: maxValue
            value: Theme[bind]
            onMoved: Theme[bind] = Math.round(value)
        }
    }

    ColorDialog {
        id: picker
        property string targetBind: ""
        onAccepted: {
            Theme[targetBind] = picker.color.toString()
        }
    }

    Dialog {
        id: exportDialog
        title: qsTr("Theme JSON")
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
        title: qsTr("Paste theme JSON")
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
                ApplicationWindow.window.showToast(qsTr("Invalid JSON"))
            }
            importField.text = ""
        }
    }

    Component.onCompleted: ProfileManager.refresh()
}
