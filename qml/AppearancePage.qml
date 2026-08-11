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
            width: parent.width
            spacing: Theme.spacingMd

            // ── Header & preset picker ──
            Label {
                Layout.leftMargin: Theme.paddingLg
                Layout.topMargin: Theme.paddingLg
                text: qsTr("Appearance")
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
            }

            RowLayout {
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Label { text: qsTr("Preset"); color: Theme.windowFg; Layout.preferredWidth: 100 }
                ComboBox {
                    id: presetCombo
                    model: JSON.parse(Theme.availablePresets())
                    Layout.preferredWidth: 240
                    onActivated: Theme.applyPreset(currentText)
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Export JSON")
                    onClicked: {
                        exportDialog.text = Theme.exportJson()
                        exportDialog.open()
                    }
                }
                Button {
                    text: qsTr("Import JSON")
                    onClicked: importDialog.open()
                }
                Button {
                    text: qsTr("Reset")
                    onClicked: Theme.reset()
                }
            }

            // ── Colors ──
            SectionCard {
                title: qsTr("Colors")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    ColorRow { label: qsTr("Window background"); bind: "windowBg" }
                    ColorRow { label: qsTr("Window text");       bind: "windowFg" }
                    ColorRow { label: qsTr("Sidebar background"); bind: "sidebarBg" }
                    ColorRow { label: qsTr("Sidebar text");      bind: "sidebarFg" }
                    ColorRow { label: qsTr("Accent");            bind: "accent" }
                    ColorRow { label: qsTr("Accent text");       bind: "accentFg" }
                    ColorRow { label: qsTr("Danger");            bind: "danger" }
                    ColorRow { label: qsTr("Success");           bind: "success" }
                    ColorRow { label: qsTr("Warning");           bind: "warning" }
                    ColorRow { label: qsTr("Muted");             bind: "muted" }
                    ColorRow { label: qsTr("Border");            bind: "border" }
                    ColorRow { label: qsTr("Bubble — own bg");   bind: "bubbleBgMe" }
                    ColorRow { label: qsTr("Bubble — own fg");   bind: "bubbleFgMe" }
                    ColorRow { label: qsTr("Bubble — other bg"); bind: "bubbleBgThem" }
                    ColorRow { label: qsTr("Bubble — other fg"); bind: "bubbleFgThem" }
                }
            }

            // ── Typography ──
            SectionCard {
                title: qsTr("Typography")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Font family"); color: Theme.windowFg; Layout.preferredWidth: 140 }
                        TextField {
                            Layout.fillWidth: true
                            text: Theme.fontFamily
                            color: Theme.windowFg
                            onEditingFinished: Theme.fontFamily = text
                            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Monospace family"); color: Theme.windowFg; Layout.preferredWidth: 140 }
                        TextField {
                            Layout.fillWidth: true
                            text: Theme.fontFamilyMono
                            color: Theme.windowFg
                            onEditingFinished: Theme.fontFamilyMono = text
                            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm; border.color: Theme.border; border.width: 1 }
                        }
                    }
                    IntRow { label: qsTr("Size XS"); bind: "fontSizeXs"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size SM"); bind: "fontSizeSm"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size MD"); bind: "fontSizeMd"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size LG"); bind: "fontSizeLg"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size XL"); bind: "fontSizeXl"; minValue: 6; maxValue: 64 }
                }
            }

            // ── Geometry ──
            SectionCard {
                title: qsTr("Geometry")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    IntRow { label: qsTr("Radius SM"); bind: "radiusSm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Radius MD"); bind: "radiusMd"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Radius LG"); bind: "radiusLg"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding XS"); bind: "paddingXs"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding SM"); bind: "paddingSm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding MD"); bind: "paddingMd"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding LG"); bind: "paddingLg"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing XS"); bind: "spacingXs"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing SM"); bind: "spacingSm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing MD"); bind: "spacingMd"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing LG"); bind: "spacingLg"; minValue: 0; maxValue: 64 }
                }
            }

            // ── Message bubbles ──
            SectionCard {
                title: qsTr("Message bubbles")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    IntRow { label: qsTr("Bubble radius");     bind: "bubbleRadius";       minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble padding H");  bind: "bubblePaddingH";    minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble padding V");  bind: "bubblePaddingV";    minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble max width %"); bind: "bubbleMaxWidthPct"; minValue: 30; maxValue: 100 }

                    RowLayout {
                        Layout.fillWidth: true
                        Switch {
                            id: tailSwitch
                            text: qsTr("Bubble tail")
                            checked: Theme.bubbleTail
                            contentItem: Label {
                                text: tailSwitch.text
                                color: Theme.windowFg
                                leftPadding: tailSwitch.indicator.width + tailSwitch.spacing
                            }
                            onToggled: Theme.bubbleTail = checked
                        }
                    }
                }
            }

            // ── Avatars ──
            SectionCard {
                title: qsTr("Avatars")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    IntRow { label: qsTr("Size SM");        bind: "avatarSizeSm"; minValue: 16; maxValue: 96 }
                    IntRow { label: qsTr("Size MD");        bind: "avatarSizeMd"; minValue: 16; maxValue: 128 }
                    IntRow { label: qsTr("Size LG");        bind: "avatarSizeLg"; minValue: 16; maxValue: 256 }
                    IntRow { label: qsTr("Corner radius");  bind: "avatarRadius";  minValue: 0; maxValue: 128 }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Shape"); color: Theme.windowFg; Layout.preferredWidth: 140 }
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
            SectionCard {
                title: qsTr("Behavior")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg

                    Switch { id: compactSwitch; text: qsTr("Compact mode"); checked: Theme.compactMode; onToggled: Theme.compactMode = checked
                        contentItem: Label { text: compactSwitch.text; color: Theme.windowFg; leftPadding: compactSwitch.indicator.width + compactSwitch.spacing } }
                    Switch { id: tsSwitch; text: qsTr("Show timestamps"); checked: Theme.showTimestamps; onToggled: Theme.showTimestamps = checked
                        contentItem: Label { text: tsSwitch.text; color: Theme.windowFg; leftPadding: tsSwitch.indicator.width + tsSwitch.spacing } }
                    Switch { id: avSwitch; text: qsTr("Show avatars"); checked: Theme.showAvatars; onToggled: Theme.showAvatars = checked
                        contentItem: Label { text: avSwitch.text; color: Theme.windowFg; leftPadding: avSwitch.indicator.width + avSwitch.spacing } }
                    Switch { id: animSwitch; text: qsTr("Animate bubbles"); checked: Theme.animateBubbles; onToggled: Theme.animateBubbles = checked
                        contentItem: Label { text: animSwitch.text; color: Theme.windowFg; leftPadding: animSwitch.indicator.width + animSwitch.spacing } }
                    IntRow { label: qsTr("Animation duration (ms)"); bind: "animationDurationMs"; minValue: 0; maxValue: 1000 }
                }
            }

            // ── Scrollbars ──
            SectionCard {
                title: qsTr("Scrollbars")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.paddingLg
                Layout.rightMargin: Theme.paddingLg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacingSm
                    columnSpacing: Theme.spacingLg
                    IntRow { label: qsTr("Width");  bind: "scrollbarSize";   minValue: 2; maxValue: 32 }
                    IntRow { label: qsTr("Radius"); bind: "scrollbarRadius"; minValue: 0; maxValue: 16 }
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: 64 }
        }
    }

    // ─── Inline components ──────────────────────────────────────

    // A titled card containing arbitrary children.
    component SectionCard: Rectangle {
        id: card
        property string title: ""
        color: Theme.sidebarBg
        radius: Theme.radiusMd
        implicitHeight: sectionInner.implicitHeight + Theme.paddingMd * 2

        ColumnLayout {
            id: sectionInner
            anchors.fill: parent
            anchors.margins: Theme.paddingMd
            spacing: Theme.spacingSm

            Label {
                text: card.title
                color: Theme.accent
                font.pixelSize: Theme.fontSizeMd
                font.bold: true
            }
        }
    }

    // A color row: label, swatch, hex field, picker button.
    component ColorRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 200 }

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 6
            color: Theme[bind]
            border.color: Theme.border; border.width: 1
        }

        TextField {
            id: hexField
            Layout.fillWidth: true
            text: Theme[bind]
            color: Theme.windowFg
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
            text: qsTr("Pick")
            onClicked: {
                picker.targetBind = bind
                picker.color = Theme[bind]
                picker.open()
            }
        }
    }

    // Integer row with − / + / slider / numeric display.
    component IntRow: RowLayout {
        property string label
        property string bind
        property int minValue: 0
        property int maxValue: 100
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        Label { text: label; color: Theme.windowFg; Layout.preferredWidth: 200 }

        Button {
            text: "−"
            enabled: Theme[bind] > minValue
            onClicked: Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](Theme[bind] - 1)
        }
        Label {
            Layout.preferredWidth: 60
            text: Theme[bind]
            color: Theme.windowFg
            horizontalAlignment: Qt.AlignHCenter
        }
        Button {
            text: "+"
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
        width: 600
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
        width: 600
        contentItem: TextArea {
            id: importField
            wrapMode: TextArea.Wrap
            color: Theme.windowFg
            background: Rectangle { color: Theme.sidebarBg; radius: Theme.radiusSm }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (!Theme.importJson(importField.text)) {
                // Show error toast from main.qml
                ApplicationWindow.window.showToast(qsTr("Invalid JSON"))
            }
            importField.text = ""
        }
    }
}
