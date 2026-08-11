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

                    Switch { id: compactSwitch; text: qsTr("Compact mode"); checked: Theme.compactMode; onToggled: Theme.compactMode = checked }
                    Switch { id: tsSwitch; text: qsTr("Show timestamps"); checked: Theme.showTimestamps; onToggled: Theme.showTimestamps = checked }
                    Switch { id: avSwitch; text: qsTr("Show avatars"); checked: Theme.showAvatars; onToggled: Theme.showAvatars = checked }
                    Switch { id: animSwitch; text: qsTr("Animate bubbles"); checked: Theme.animateBubbles; onToggled: Theme.animateBubbles = checked }
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

    // ─── Inline components ──────────────────────────────────────

    // A color row: label, swatch, hex field.
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
                    Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](v)
                } else {
                    text = Theme[bind]
                }
            }
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
        }

        Button {
            text: qsTr("🎨")
            font.pixelSize: Theme.fontSizeSm
            onClicked: {
                picker.targetBind = bind
                picker.color = Theme[bind]
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

    // Integer row with − / + / slider / numeric display.
    component IntRow: RowLayout {
        property string label
        property string bind
        property int minValue: 0
        property int maxValue: 100
        Layout.fillWidth: true
        spacing: 4

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 100; font.pixelSize: Theme.fontSizeSm }

        Button {
            text: "−"
            font.pixelSize: Theme.fontSizeSm
            enabled: Theme[bind] > minValue
            onClicked: Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](Theme[bind] - 1)
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
            onClicked: Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](Theme[bind] + 1)
        }
        Slider {
            Layout.fillWidth: true
            from: minValue
            to: maxValue
            value: Theme[bind]
            onMoved: Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](Math.round(value))
        }
    }

    // ─── Shared dialogs ───

    ColorDialog {
        id: picker
        property string targetBind: ""
        onAccepted: {
            Theme["set" + targetBind.charAt(0).toUpperCase() + targetBind.slice(1)](picker.color.toString())
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
}
