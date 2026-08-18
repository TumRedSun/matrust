// FileBrowserDialog.qml — custom file picker with multi-select and hidden-file support.
//
// The stock QtQuick.Dialogs FileDialog doesn't expose a "show hidden files"
// toggle, and on most Linux desktops the native dialog hides dotfiles by
// default (Ctrl+H works in some file managers but not all). This custom
// dialog uses MatrixClient.listDirectory() (Rust std::fs::read_dir) so we
// have full control over what's shown.
//
// Features:
//   - Multi-file selection (Discord-style attachment queue)
//   - Toggle to show/hide dotfiles
//   - Breadcrumb-style path navigation
//   - Keyboard: Esc closes, Enter on a file selects it, Backspace goes up
//
// Usage:
//   FileBrowserDialog {
//       id: fileBrowser
//       onFilesSelected: function(paths) { /* paths is a JS array of strings */ }
//   }
//   fileBrowser.open()

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Dialog {
    id: dialog
    modal: true
    title: qsTr("Choose files to send")
    width: 720
    height: 480
    standardButtons: Dialog.Open | Dialog.Cancel
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Signal emitted when the user clicks Open with at least one file selected.
    // `paths` is a JS array of absolute filesystem paths.
    signal filesSelected(var paths)

    property string currentPath: MatrixClient.homeDir()
    property bool showHidden: false
    property var selectedPaths: []   // JS array of strings
    property var entries: []         // Parsed JSON from listDirectory

    function open() {
        selectedPaths = []
        loadDir(currentPath)
        visible = true
    }

    function loadDir(path) {
        currentPath = path
        var json = MatrixClient.listDirectory(path, showHidden)
        try {
            entries = JSON.parse(json)
        } catch (e) {
            entries = []
            console.log("FileBrowserDialog: failed to parse JSON: " + e)
        }
        // Don't clear selection — user might want to keep selected files
        // from a previously-browsed directory.
    }

    function toggleSelected(path) {
        var idx = selectedPaths.indexOf(path)
        if (idx >= 0) {
            // Remove
            var copy = selectedPaths.slice()
            copy.splice(idx, 1)
            selectedPaths = copy
        } else {
            // Add
            var copy = selectedPaths.slice()
            copy.push(path)
            selectedPaths = copy
        }
    }

    function isSelected(path) {
        return selectedPaths.indexOf(path) >= 0
    }

    function goUp() {
        var p = currentPath
        if (p === "/" || p === "") return
        var idx = p.lastIndexOf("/")
        if (idx <= 0) {
            currentPath = "/"
            loadDir("/")
        } else {
            var parent = p.substring(0, idx)
            loadDir(parent)
        }
    }

    function pathPartName(p) {
        var idx = p.lastIndexOf("/")
        if (idx < 0) return p
        return p.substring(idx + 1)
    }

    onAccepted: {
        if (selectedPaths.length > 0) {
            filesSelected(selectedPaths)
        }
    }

    onOpened: loadDir(currentPath)

    contentItem: ColumnLayout {
        spacing: 8

        // ── Path bar ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Button {
                text: qsTr("\u2191")  // ↑
                onClicked: goUp()
                ToolTip.text: qsTr("Go to parent directory")
                ToolTip.visible: hovered
            }
            Button {
                text: qsTr("/")
                onClicked: loadDir("/")
                ToolTip.text: qsTr("Go to filesystem root")
                ToolTip.visible: hovered
            }
            Button {
                text: qsTr("\uD83C\uDFE0")  // 🏠
                onClicked: loadDir(MatrixClient.homeDir())
                ToolTip.text: qsTr("Go to home directory")
                ToolTip.visible: hovered
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 32
                clip: true
                Label {
                    text: dialog.currentPath
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSm
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Show hidden files toggle
            CheckBox {
                text: qsTr("Hidden")
                checked: dialog.showHidden
                onToggled: {
                    dialog.showHidden = checked
                    loadDir(dialog.currentPath)
                }
                ToolTip.text: qsTr("Show files and directories starting with '.'")
                ToolTip.visible: hovered
            }
        }

        // ── File list ──
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: listView
                model: dialog.entries
                spacing: 1

                delegate: Rectangle {
                    width: listView.width
                    height: 32
                    color: {
                        if (isSelected(fullPath)) return Theme.accent
                        if (mouseArea.containsMouse) return Theme.sidebarBg
                        return "transparent"
                    }

                    property string fullPath: dialog.currentPath + "/" + modelData.name

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Label {
                            text: modelData.is_dir ? "\uD83D\uDCC1" : "\uD83D\uDCC4"  // 📁 / 📄
                            font.pixelSize: Theme.fontSizeMd
                            Layout.preferredWidth: 20
                        }
                        Label {
                            text: modelData.name
                            color: isSelected(fullPath) ? Theme.accentFg
                                  : (modelData.is_dir ? Theme.sidebarFg : Theme.windowFg)
                            font.pixelSize: Theme.fontSizeSm
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: modelData.is_dir ? "" : formatBytes(modelData.size)
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeXs
                            visible: !modelData.is_dir
                        }
                        // Selection checkbox
                        CheckBox {
                            checked: isSelected(fullPath)
                            visible: !modelData.is_dir
                            onClicked: toggleSelected(fullPath)
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onDoubleClicked: {
                            if (modelData.is_dir) {
                                loadDir(fullPath)
                            } else {
                                toggleSelected(fullPath)
                            }
                        }
                        onClicked: {
                            if (modelData.is_dir) {
                                loadDir(fullPath)
                            } else {
                                toggleSelected(fullPath)
                            }
                        }
                    }
                }
            }
        }

        // ── Selection summary ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.sidebarBg
            radius: Theme.radiusSm

            Label {
                anchors.centerIn: parent
                text: dialog.selectedPaths.length === 0
                      ? qsTr("No files selected")
                      : qsTr("%n file(s) selected", "", dialog.selectedPaths.length)
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSm
            }
        }
    }

    function formatBytes(b) {
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }
}
