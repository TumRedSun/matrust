// MessageBubble.qml — one message, themed from Theme singleton.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Item {
    id: root
    // Bindable properties.
    property string eventId
    property string sender
    property string avatarUrl
    property string body
    property string bodyHtml
    property var ts: 0
    property bool isOwn: false
    property string kind: "text"
    property string mxcUrl
    property string fileName
    property var fileSize: 0
    property string mimeType
    property string roomId

    implicitHeight: layout.implicitHeight

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacing_sm
        layoutDirection: root.isOwn ? Qt.RightToLeft : Qt.LeftToRight

        // Avatar (optional)
        Rectangle {
            visible: Theme.show_avatars && !root.isOwn
            Layout.preferredWidth: Theme.avatar_size_sm
            Layout.preferredHeight: Theme.avatar_size_sm
            Layout.alignment: Qt.AlignTop
            radius: Theme.avatar_shape === "circle" ? Theme.avatar_size_sm/2
                    : (Theme.avatar_shape === "square" ? 0 : Theme.avatar_radius)
            color: Theme.accent
            opacity: 0.3
            Label {
                anchors.centerIn: parent
                text: root.sender.length > 0 ? root.sender.charAt(0).toUpperCase() : "?"
                color: Theme.accent_fg
                font.pixelSize: Theme.font_size_sm
                font.bold: true
            }
        }

        // Bubble
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width * (Theme.bubble_max_width_pct / 100.0)
            Layout.alignment: root.isOwn ? Qt.AlignRight : Qt.AlignLeft
            color: root.isOwn ? Theme.bubble_bg_me : Theme.bubble_bg_them
            radius: Theme.bubble_radius
            // Tail (subtle asymmetric corner)
            Rectangle {
                visible: Theme.bubble_tail
                anchors.bottom: parent.bottom
                anchors.left: root.isOwn ? undefined : parent.left
                anchors.right: root.isOwn ? parent.right : undefined
                anchors.leftMargin: -4
                anchors.rightMargin: -4
                width: 12; height: 12
                color: parent.color
                radius: 4
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // Sender label (for non-own messages only)
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubble_padding_h
                    Layout.rightMargin: Theme.bubble_padding_h
                    Layout.topMargin: Theme.bubble_padding_v
                    visible: !root.isOwn && root.sender.length > 0
                    text: root.sender
                    color: Theme.accent
                    font.pixelSize: Theme.font_size_xs
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Content area
                Loader {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubble_padding_h
                    Layout.rightMargin: Theme.bubble_padding_h
                    Layout.topMargin: root.isOwn || root.sender.length === 0
                                      ? Theme.bubble_padding_v : 2
                    Layout.bottomMargin: Theme.bubble_padding_v
                    sourceComponent: {
                        switch (root.kind) {
                            case "image": return imageComp
                            case "video": return videoComp
                            case "audio": return audioComp
                            case "file":  return fileComp
                            case "system": return systemComp
                            default: return textComp
                        }
                    }
                }
            }
        }
    }

    // ─── Components ────────────────────────────────────────────────
    Component {
        id: textComp
        ColumnLayout {
            spacing: 2
            TextEdit {
                Layout.fillWidth: true
                textFormat: root.bodyHtml.length > 0 ? Text.RichText : Text.PlainText
                text: root.bodyHtml.length > 0 ? root.bodyHtml : root.body
                wrapMode: Text.Wrap
                readOnly: true
                selectByMouse: true
                color: root.isOwn ? Theme.bubble_fg_me : Theme.bubble_fg_them
                font.pixelSize: Theme.font_size_md
                onLinkActivated: Qt.openUrlExternally(link)
            }
            Label {
                visible: Theme.show_timestamps && root.ts > 0
                text: formatTime(root.ts)
                color: root.isOwn ? Theme.bubble_fg_me : Theme.muted
                font.pixelSize: Theme.font_size_xs
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    Component {
        id: imageComp
        ColumnLayout {
            spacing: 4
            Image {
                Layout.fillWidth: true
                Layout.maximumHeight: 320
                fillMode: Image.PreserveAspectFit
                source: root.mxcUrl.length > 0 ? "image://matrix/" + root.mxcUrl : ""
                asynchronous: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onDoubleClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName)
                }
            }
            Label {
                Layout.alignment: Qt.AlignRight
                visible: Theme.show_timestamps && root.ts > 0
                text: formatTime(root.ts)
                color: root.isOwn ? Theme.bubble_fg_me : Theme.muted
                font.pixelSize: Theme.font_size_xs
            }
        }
    }

    Component {
        id: videoComp
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing_sm
                Label { text: "🎬"; font.pixelSize: Theme.font_size_lg }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: root.fileName
                        color: root.isOwn ? Theme.bubble_fg_me : Theme.bubble_fg_them
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: qsTr("Video · click to download")
                        color: Theme.muted
                        font.pixelSize: Theme.font_size_xs
                    }
                }
                Button {
                    text: qsTr("↓")
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName)
                }
            }
            Label {
                visible: Theme.show_timestamps && root.ts > 0
                text: formatTime(root.ts); color: Theme.muted; font.pixelSize: Theme.font_size_xs
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    Component {
        id: audioComp
        RowLayout {
            spacing: Theme.spacing_sm
            Label { text: "🎵"; font.pixelSize: Theme.font_size_lg }
            Label {
                text: root.fileName + " · " + formatBytes(root.fileSize)
                color: root.isOwn ? Theme.bubble_fg_me : Theme.bubble_fg_them
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Button { text: qsTr("↓"); onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName) }
        }
    }

    Component {
        id: fileComp
        RowLayout {
            spacing: Theme.spacing_sm
            Label { text: "📄"; font.pixelSize: Theme.font_size_lg }
            ColumnLayout {
                Layout.fillWidth: true
                Label {
                    text: root.fileName
                    color: root.isOwn ? Theme.bubble_fg_me : Theme.bubble_fg_them
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: formatBytes(root.fileSize) + (root.mimeType.length > 0 ? " · " + root.mimeType : "")
                    color: Theme.muted
                    font.pixelSize: Theme.font_size_xs
                }
            }
            Button {
                text: qsTr("Download")
                onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName)
            }
        }
    }

    Component {
        id: systemComp
        Label {
            text: root.body
            color: Theme.muted
            font.pixelSize: Theme.font_size_xs
            font.italic: true
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // ── Helpers ──
    function formatTime(t) {
        var d = new Date(t)
        var hh = ("0" + d.getHours()).slice(-2)
        var mm = ("0" + d.getMinutes()).slice(-2)
        return hh + ":" + mm
    }
    function formatBytes(b) {
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }
}
