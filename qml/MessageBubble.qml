// MessageBubble.qml — one message, themed from Theme singleton.
//
// Layout strategy
// ───────────────
// The root is an Item. For the ListView to size each delegate
// correctly, the root's `implicitHeight` MUST be set explicitly —
// otherwise the delegate defaults to height 0 and every row overlaps
// the next (this was the bug that produced the "dense block of
// overlapping text" screenshot).
//
// We compute `implicitHeight` from whichever child is visible:
//   - system / encrypted messages → systemLabel.implicitHeight + padding
//   - regular messages            → chatRow.implicitHeight
//
// System messages (joins, leaves, profile changes) render as a
// centered muted italic line — no avatar, no bubble.
//
// Encrypted-but-undecryptable messages render the same way (centered,
// muted, with a lock glyph) so they don't look like broken bubbles.
//
// Regular messages render with avatar + bubble, mirrored for own
// messages via layoutDirection.
//
// Media bubbles (image/video/audio/file):
//   We do NOT try to inline-render the media — that would require a
//   QML image provider (not registered in this build) and decryption
//   for E2EE media. Instead we show a tile with the file name, size,
//   mime type, and a Download button. Clicking the button calls
//   MatrixClient.downloadMedia(roomId, mediaSourceJson, fileName),
//   which uses the SDK to fetch + (if needed) decrypt the bytes and
//   save them to the user's Downloads directory. The download
//   completes via the `fileDownloaded` signal.

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
    property string mediaSourceJson
    property string fileName
    property var fileSize: 0
    property string mimeType
    property string roomId

    // Max bubble width as fraction of parent width
    readonly property real maxBubbleWidth: width * (Theme.bubbleMaxWidthPct / 100.0)

    // Whether this message renders in the "centered single-line" style
    // (system notices and undecryptable encrypted messages).
    readonly property bool isCentered: root.kind === "system" || root.kind === "encrypted"

    // ── Delegate height ──
    // ListView uses the delegate's `implicitHeight` (when no explicit
    // `height` is set) to size each row. Without this, every row
    // collapses to height 0 and the delegates overlap.
    implicitHeight: isCentered
                    ? systemLabel.implicitHeight + Theme.paddingSm * 2
                    : chatRow.implicitHeight

    // ── Centered layout (system + encrypted messages) ──
    Label {
        id: systemLabel
        visible: root.isCentered
        anchors.centerIn: parent
        width: parent.width - Theme.paddingMd * 2
        text: {
            if (root.kind === "encrypted") {
                return qsTr("Encrypted message — decryption pending")
            }
            return root.body.length > 0 ? root.body : qsTr("(event)")
        }
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSm
        font.italic: true
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Regular message layout (avatar + bubble) ──
    RowLayout {
        id: chatRow
        visible: !root.isCentered
        anchors.fill: parent
        spacing: Theme.showAvatars && !root.isOwn ? Theme.spacingSm : 0
        layoutDirection: root.isOwn ? Qt.RightToLeft : Qt.LeftToRight

        // ── Avatar (only for non-own messages) ──
        Rectangle {
            visible: Theme.showAvatars && !root.isOwn
            Layout.preferredWidth: visible ? Theme.avatarSizeSm : 0
            Layout.preferredHeight: visible ? Theme.avatarSizeSm : 0
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

        // ── Bubble ──
        Rectangle {
            id: bubble
            Layout.alignment: Qt.AlignTop
            // Do NOT use Layout.fillWidth — it would stretch to fill the
            // remaining space, pushing the bubble all the way across.
            // Instead, let the bubble size to its content and cap it.
            Layout.maximumWidth: root.maxBubbleWidth
            Layout.preferredWidth: Math.min(bubbleContent.implicitWidth + Theme.bubblePaddingH * 2,
                                            root.maxBubbleWidth)
            Layout.preferredHeight: bubbleContent.implicitHeight

            color: root.isOwn ? Theme.bubbleBgMe : Theme.bubbleBgThem
            radius: Theme.bubbleRadius

            ColumnLayout {
                id: bubbleContent
                anchors.fill: parent
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
                    id: contentLoader
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.topMargin: root.isOwn || root.sender.length === 0
                                      ? Theme.bubblePaddingV : 2
                    Layout.bottomMargin: Theme.bubblePaddingV
                    Layout.minimumHeight: item ? item.implicitHeight : 0
                    sourceComponent: {
                        switch (root.kind) {
                            case "image": return imageComp
                            case "video": return videoComp
                            case "audio": return audioComp
                            case "file":  return fileComp
                            // "system" and "encrypted" never reach here
                            // because they take the centered layout
                            // path above. Keep them as a safety net.
                            case "system": return systemInlineComp
                            default: return textComp
                        }
                    }
                }
            }
        }

        // ── Spacer: fills remaining space so bubble doesn't stretch ──
        // For own messages (RightToLeft), this spacer is on the LEFT,
        // pushing the bubble to the right edge.
        // For other messages (LeftToRight), this spacer is on the RIGHT,
        // keeping the bubble at the left edge.
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
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

    // ── Image message ──
    // We don't try to render the image inline (would need a QML image
    // provider + E2EE decryption). Instead we show a tile with the
    // file name, size, and a Download button. The body (caption) is
    // shown above the tile if present.
    Component {
        id: imageComp
        ColumnLayout {
            spacing: 4
            // Caption (if the sender added one)
            Label {
                Layout.fillWidth: true
                visible: root.body.length > 0 && root.body !== root.fileName
                text: root.body
                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                font.pixelSize: Theme.fontSizeMd
                wrapMode: Text.Wrap
            }
            // Image tile: icon + file info + Download button
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label {
                    text: "\uD83D\uDDBC"  // 🖼
                    font.pixelSize: Theme.fontSizeLg
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: root.fileName.length > 0 ? root.fileName : qsTr("Image")
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: formatBytes(root.fileSize)
                              + (root.mimeType.length > 0 ? " \u00B7 " + root.mimeType : "")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("\u2193")  // ↓
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
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
        id: videoComp
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label { text: "\uD83C\uDFAC"; font.pixelSize: Theme.fontSizeLg }  // 🎬
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: root.fileName.length > 0 ? root.fileName : qsTr("Video")
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: formatBytes(root.fileSize)
                              + (root.mimeType.length > 0 ? " \u00B7 " + root.mimeType : "")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("\u2193")
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
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
        id: audioComp
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label { text: "\uD83C\uDFB5"; font.pixelSize: Theme.fontSizeLg }  // 🎵
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: root.fileName.length > 0 ? root.fileName : qsTr("Audio")
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: formatBytes(root.fileSize)
                              + (root.mimeType.length > 0 ? " \u00B7 " + root.mimeType : "")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("\u2193")
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
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
        id: fileComp
        ColumnLayout {
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label { text: "\uD83D\uDCC4"; font.pixelSize: Theme.fontSizeLg }  // 📄
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: root.fileName.length > 0 ? root.fileName : qsTr("File")
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        font.pixelSize: Theme.fontSizeSm
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: formatBytes(root.fileSize)
                              + (root.mimeType.length > 0 ? " \u00B7 " + root.mimeType : "")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("\u2193")
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
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

    // Safety-net inline renderer for the rare case a "system" kind
    // ends up inside a bubble (shouldn't happen because isCentered
    // catches it first, but keep it for robustness).
    Component {
        id: systemInlineComp
        Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.body
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSm
            font.italic: true
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
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
