// AppearancePage.qml — fully customizable theme editor with live preview.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    id: appearanceRoot
    color: Theme.windowBg

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: editor
            width: parent.width - Theme.paddingLg * 2
            x: Theme.paddingLg
            spacing: Theme.spacingMd

            // ── Header & preset picker ──
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
                    Layout.preferredWidth: Theme.comboBoxMdW
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

                    Switch { id: compactSwitch; text: Tr.tr(Theme.language, "Compact mode"); checked: Theme.compactMode; onToggled: Theme.compactMode = checked }
                    Switch { id: tsSwitch; text: Tr.tr(Theme.language, "Show timestamps"); checked: Theme.showTimestamps; onToggled: Theme.showTimestamps = checked }
                    Switch { id: avSwitch; text: Tr.tr(Theme.language, "Show avatars"); checked: Theme.showAvatars; onToggled: Theme.showAvatars = checked }
                    Switch { id: animSwitch; text: Tr.tr(Theme.language, "Animate bubbles"); checked: Theme.animateBubbles; onToggled: Theme.animateBubbles = checked }
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

            Item { Layout.fillHeight: true; Layout.preferredHeight: Theme.previewBoxH }
        }
    }

    // ─── Inline components ──────────────────────────────────────

    // A color row: label, swatch, hex field.
    component ColorRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }

        Rectangle {
            Layout.preferredWidth: Theme.colorSwatchSize
            Layout.preferredHeight: Theme.colorSwatchSize
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
            text: Tr.tr(Theme.language, "🎨")
            font.pixelSize: Theme.fontSizeSm
            onClicked: {
                picker.targetBind = bind
                picker.selectedColor = Theme[bind]
                picker.open()
            }
        }
    }

    // String row for font family fields.
    component StringRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }
        TextField {
            Layout.fillWidth: true
            text: Theme[bind]
            color: Theme.windowFg
            font.pixelSize: Theme.fontSizeSm
            onEditingFinished: Theme[bind] = text
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
        }
    }

    // Integer row: label + SpinBox + live preview (no sliders or −/+ buttons).
    // Mirrors the IntRow in SettingsOverlay.qml — kept in sync so the
    // standalone AppearancePage and the embedded one look identical.
    component IntRow: RowLayout {
        property string label
        property string bind
        property int minValue: 0
        property int maxValue: 100
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; font.pixelSize: Theme.fontSizeSm }

        SpinBox {
            id: spin
            Layout.preferredWidth: Theme.spinBoxW
            from: minValue
            to: maxValue
            value: Theme[bind]
            onValueModified: Theme[bind] = value
            editable: true
            font.pixelSize: Theme.fontSizeSm
        }

        Rectangle {
            id: previewBox
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.previewBoxH
            color: Theme.sidebarBg
            radius: Theme.radiusSm
            border.color: Theme.border
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.margins: 4

                Rectangle {
                    visible: bind.indexOf("adius") >= 0 || bind === "avatarRadius" || bind === "scrollbarRadius"
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    radius: Math.min(Theme[bind], 24)
                    color: Theme.accent
                }

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

                Text {
                    visible: bind.indexOf("ontSize") >= 0 || bind.indexOf("imationDuration") >= 0
                    anchors.centerIn: parent
                    text: "Aa"
                    color: Theme.windowFg
                    font.pixelSize: Math.min(Theme[bind], 28)
                }

                Rectangle {
                    visible: bind.indexOf("avatarSize") >= 0 || bind.indexOf("crollbarSize") >= 0
                    anchors.centerIn: parent
                    width: Math.min(Theme[bind], parent.width)
                    height: bind.indexOf("crollbarSize") >= 0 ? Math.min(Theme[bind], parent.height) : Math.min(Theme[bind], parent.width)
                    radius: bind === "avatarSizeSm" || bind === "avatarSizeMd" || bind === "avatarSizeLg" ? width / 2 : 2
                    color: Theme.accent
                    opacity: 0.6
                }

                Rectangle {
                    visible: bind.indexOf("axWidth") >= 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Theme[bind] / 100
                    height: 8
                    color: Theme.accent
                    radius: 2
                }
            }
        }
    }

    // ─── Shared dialogs ───

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
        width: Theme.dialogLgW
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
        width: Theme.dialogLgW
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
}
