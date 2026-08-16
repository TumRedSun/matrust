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

    // Explicit height from the layout.  We add a small vertical pad
    // so bubbles never collapse to 0 and have a guaranteed gap even
    // if the ListView spacing is small.
    height: layout.implicitHeight + 4

    RowLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Do NOT anchor bottom — let the layout calculate its
        // own height from its contents so implicitHeight is correct.
        spacing: Theme.spacingSm
        layoutDirection: root.isOwn ? Qt.RightToLeft : Qt.LeftToRight

        // Avatar (optional)
        Rectangle {
            visible: Theme.showAvatars && !root.isOwn
            Layout.preferredWidth: Theme.avatarSizeSm
            Layout.preferredHeight: Theme.avatarSizeSm
            Layout.alignment: Qt.AlignTop
            radius: Theme.avatarShape === "circle" ? Theme.avatarSizeSm/2
                    : (Theme.avatarShape === "square" ? 0 : Theme.avatarRadius)
            color: Theme.accent
            opacity: 0.3
            Label {
                anchors.centerIn: parent
                text: root.sender.length > 0 ? root.sender.charAt(0).toUpperCase() : "?"
                color: Theme.accentFg
                font.pixelSize: Theme.fontSizeSm
                font.bold: true
            }
        }

        // Bubble
        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: parent.width * (Theme.bubbleMaxWidthPct / 100.0)
            Layout.alignment: root.isOwn ? Qt.AlignRight : Qt.AlignLeft
            color: root.isOwn ? Theme.bubbleBgMe : Theme.bubbleBgThem
            radius: Theme.bubbleRadius
            // Tail (subtle asymmetric corner)
            Rectangle {
                visible: Theme.bubbleTail
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
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.topMargin: Theme.bubblePaddingV
                    visible: !root.isOwn && root.sender.length > 0
                    text: root.sender
                    color: Theme.accent
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Content area
                Loader {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.topMargin: root.isOwn || root.sender.length === 0
                                      ? Theme.bubblePaddingV : 2
                    Layout.bottomMargin: Theme.bubblePaddingV
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
                text: root.bodyHtml.length > 0 ? root.bodyHtml
                      : (root.body.length > 0 ? root.body : qsTr("(empty)"))
                wrapMode: Text.Wrap
                readOnly: true
                selectByMouse: true
                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                font.pixelSize: Theme.fontSizeMd
                onLinkActivated: Qt.openUrlExternally(link)
            }
            Label {
                visible: Theme.showTimestamps && root.ts > 0
                text: formatTime(root.ts)
                color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                font.pixelSize: Theme.fontSizeXs
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
                // Show a placeholder while loading / on error
                Label {
                    anchors.centerIn: parent
                    visible: parent.status === Image.Loading
                    text: qsTr("Loading…")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Label {
                    anchors.centerIn: parent
                    visible: parent.status === Image.Error
                    text: qsTr("Image unavailable")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onDoubleClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName)
                }
            }
            Label {
                Layout.alignment: Qt.AlignRight
                visible: Theme.showTimestamps && root.ts > 0
                text: formatTime(root.ts)
                color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                font.pixelSize: Theme.fontSizeXs
            }
        }
    }

    Component {
        id: videoComp
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label { text: "🎬"; font.pixelSize: Theme.fontSizeLg }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: root.fileName
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: qsTr("Video · click to download")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("↓")
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName)
                }
            }
            Label {
                visible: Theme.showTimestamps && root.ts > 0
                text: formatTime(root.ts); color: Theme.muted; font.pixelSize: Theme.fontSizeXs
                Layout.alignment: Qt.AlignRight
            }
        }
    }

    Component {
        id: audioComp
        RowLayout {
            spacing: Theme.spacingSm
            Label { text: "🎵"; font.pixelSize: Theme.fontSizeLg }
            Label {
                text: root.fileName + " · " + formatBytes(root.fileSize)
                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Button { text: qsTr("↓"); onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName) }
        }
    }

    Component {
        id: fileComp
        RowLayout {
            spacing: Theme.spacingSm
            Label { text: "📄"; font.pixelSize: Theme.fontSizeLg }
            ColumnLayout {
                Layout.fillWidth: true
                Label {
                    text: root.fileName
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: formatBytes(root.fileSize) + (root.mimeType.length > 0 ? " · " + root.mimeType : "")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
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
            font.pixelSize: Theme.fontSizeXs
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
