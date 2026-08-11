// AppearancePage.qml — fully customizable theme editor with live preview.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    id: appearanceRoot
    color: Theme.window_bg

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            id: editor
            width: parent.width
            spacing: Theme.spacing_md

            // ── Header & preset picker ──
            Label {
                Layout.leftMargin: Theme.padding_lg
                Layout.topMargin: Theme.padding_lg
                text: qsTr("Appearance")
                color: Theme.window_fg
                font.pixelSize: Theme.font_size_xl
                font.bold: true
            }

            RowLayout {
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg
                Layout.fillWidth: true
                spacing: Theme.spacing_sm

                Label { text: qsTr("Preset"); color: Theme.window_fg; Layout.preferredWidth: 100 }
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
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    ColorRow { label: qsTr("Window background"); bind: "window_bg" }
                    ColorRow { label: qsTr("Window text");       bind: "window_fg" }
                    ColorRow { label: qsTr("Sidebar background"); bind: "sidebar_bg" }
                    ColorRow { label: qsTr("Sidebar text");      bind: "sidebar_fg" }
                    ColorRow { label: qsTr("Accent");            bind: "accent" }
                    ColorRow { label: qsTr("Accent text");       bind: "accent_fg" }
                    ColorRow { label: qsTr("Danger");            bind: "danger" }
                    ColorRow { label: qsTr("Success");           bind: "success" }
                    ColorRow { label: qsTr("Warning");           bind: "warning" }
                    ColorRow { label: qsTr("Muted");             bind: "muted" }
                    ColorRow { label: qsTr("Border");            bind: "border" }
                    ColorRow { label: qsTr("Bubble — own bg");   bind: "bubble_bg_me" }
                    ColorRow { label: qsTr("Bubble — own fg");   bind: "bubble_fg_me" }
                    ColorRow { label: qsTr("Bubble — other bg"); bind: "bubble_bg_them" }
                    ColorRow { label: qsTr("Bubble — other fg"); bind: "bubble_fg_them" }
                }
            }

            // ── Typography ──
            SectionCard {
                title: qsTr("Typography")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Font family"); color: Theme.window_fg; Layout.preferredWidth: 140 }
                        TextField {
                            Layout.fillWidth: true
                            text: Theme.font_family
                            color: Theme.window_fg
                            onEditingFinished: Theme.font_family = text
                            background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Monospace family"); color: Theme.window_fg; Layout.preferredWidth: 140 }
                        TextField {
                            Layout.fillWidth: true
                            text: Theme.font_family_mono
                            color: Theme.window_fg
                            onEditingFinished: Theme.font_family_mono = text
                            background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
                        }
                    }
                    IntRow { label: qsTr("Size XS"); bind: "font_size_xs"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size SM"); bind: "font_size_sm"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size MD"); bind: "font_size_md"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size LG"); bind: "font_size_lg"; minValue: 6; maxValue: 32 }
                    IntRow { label: qsTr("Size XL"); bind: "font_size_xl"; minValue: 6; maxValue: 64 }
                }
            }

            // ── Geometry ──
            SectionCard {
                title: qsTr("Geometry")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    IntRow { label: qsTr("Radius SM"); bind: "radius_sm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Radius MD"); bind: "radius_md"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Radius LG"); bind: "radius_lg"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding XS"); bind: "padding_xs"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding SM"); bind: "padding_sm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding MD"); bind: "padding_md"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Padding LG"); bind: "padding_lg"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing XS"); bind: "spacing_xs"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing SM"); bind: "spacing_sm"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing MD"); bind: "spacing_md"; minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Spacing LG"); bind: "spacing_lg"; minValue: 0; maxValue: 64 }
                }
            }

            // ── Message bubbles ──
            SectionCard {
                title: qsTr("Message bubbles")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    IntRow { label: qsTr("Bubble radius");     bind: "bubble_radius";       minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble padding H");  bind: "bubble_padding_h";    minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble padding V");  bind: "bubble_padding_v";    minValue: 0; maxValue: 64 }
                    IntRow { label: qsTr("Bubble max width %"); bind: "bubble_max_width_pct"; minValue: 30; maxValue: 100 }

                    RowLayout {
                        Layout.fillWidth: true
                        Switch {
                            id: tailSwitch
                            text: qsTr("Bubble tail")
                            checked: Theme.bubble_tail
                            contentItem: Label {
                                text: tailSwitch.text
                                color: Theme.window_fg
                                leftPadding: tailSwitch.indicator.width + tailSwitch.spacing
                            }
                            onToggled: Theme.bubble_tail = checked
                        }
                    }
                }
            }

            // ── Avatars ──
            SectionCard {
                title: qsTr("Avatars")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    IntRow { label: qsTr("Size SM");        bind: "avatar_size_sm"; minValue: 16; maxValue: 96 }
                    IntRow { label: qsTr("Size MD");        bind: "avatar_size_md"; minValue: 16; maxValue: 128 }
                    IntRow { label: qsTr("Size LG");        bind: "avatar_size_lg"; minValue: 16; maxValue: 256 }
                    IntRow { label: qsTr("Corner radius");  bind: "avatar_radius";  minValue: 0; maxValue: 128 }

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("Shape"); color: Theme.window_fg; Layout.preferredWidth: 140 }
                        ComboBox {
                            id: shapeCombo
                            model: ["circle", "rounded", "square"]
                            currentIndex: model.indexOf(Theme.avatar_shape)
                            onActivated: Theme.avatar_shape = currentText
                        }
                    }
                }
            }

            // ── Behavior ──
            SectionCard {
                title: qsTr("Behavior")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg

                    Switch { id: compactSwitch; text: qsTr("Compact mode"); checked: Theme.compact_mode; onToggled: Theme.compact_mode = checked
                        contentItem: Label { text: compactSwitch.text; color: Theme.window_fg; leftPadding: compactSwitch.indicator.width + compactSwitch.spacing } }
                    Switch { id: tsSwitch; text: qsTr("Show timestamps"); checked: Theme.show_timestamps; onToggled: Theme.show_timestamps = checked
                        contentItem: Label { text: tsSwitch.text; color: Theme.window_fg; leftPadding: tsSwitch.indicator.width + tsSwitch.spacing } }
                    Switch { id: avSwitch; text: qsTr("Show avatars"); checked: Theme.show_avatars; onToggled: Theme.show_avatars = checked
                        contentItem: Label { text: avSwitch.text; color: Theme.window_fg; leftPadding: avSwitch.indicator.width + avSwitch.spacing } }
                    Switch { id: animSwitch; text: qsTr("Animate bubbles"); checked: Theme.animate_bubbles; onToggled: Theme.animate_bubbles = checked
                        contentItem: Label { text: animSwitch.text; color: Theme.window_fg; leftPadding: animSwitch.indicator.width + animSwitch.spacing } }
                    IntRow { label: qsTr("Animation duration (ms)"); bind: "animation_duration_ms"; minValue: 0; maxValue: 1000 }
                }
            }

            // ── Scrollbars ──
            SectionCard {
                title: qsTr("Scrollbars")
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding_lg
                Layout.rightMargin: Theme.padding_lg

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: Theme.spacing_sm
                    columnSpacing: Theme.spacing_lg
                    IntRow { label: qsTr("Width");  bind: "scrollbar_size";   minValue: 2; maxValue: 32 }
                    IntRow { label: qsTr("Radius"); bind: "scrollbar_radius"; minValue: 0; maxValue: 16 }
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
        color: Theme.sidebar_bg
        radius: Theme.radius_md
        implicitHeight: sectionInner.implicitHeight + Theme.padding_md * 2

        ColumnLayout {
            id: sectionInner
            anchors.fill: parent
            anchors.margins: Theme.padding_md
            spacing: Theme.spacing_sm

            Label {
                text: card.title
                color: Theme.accent
                font.pixelSize: Theme.font_size_md
                font.bold: true
            }
        }
    }

    // A color row: label, swatch, hex field, picker button.
    component ColorRow: RowLayout {
        property string label
        property string bind
        Layout.fillWidth: true
        spacing: Theme.spacing_sm

        Label { text: label; color: Theme.window_fg; Layout.preferredWidth: 200 }

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
            color: Theme.window_fg
            onEditingFinished: {
                var v = text.trim()
                if (/^#[0-9a-fA-F]{3,8}$/.test(v)) {
                    Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](v)
                } else {
                    text = Theme[bind]
                }
            }
            background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm; border.color: Theme.border; border.width: 1 }
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
        spacing: Theme.spacing_sm

        Label { text: label; color: Theme.window_fg; Layout.preferredWidth: 200 }

        Button {
            text: "−"
            enabled: Theme[bind] > minValue
            onClicked: Theme["set" + bind.charAt(0).toUpperCase() + bind.slice(1)](Theme[bind] - 1)
        }
        Label {
            Layout.preferredWidth: 60
            text: Theme[bind]
            color: Theme.window_fg
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
                color: Theme.window_fg
                background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm }
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
            color: Theme.window_fg
            background: Rectangle { color: Theme.sidebar_bg; radius: Theme.radius_sm }
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
