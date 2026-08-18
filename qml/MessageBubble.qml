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
                Label {
                    anchors.centerIn: parent
                    visible: parent.status === Image.Loading
                    text: qsTr("Loading\u2026")
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
                Label { text: "\uD83C\uDFAC"; font.pixelSize: Theme.fontSizeLg }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label {
                        text: root.fileName
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Label {
                        text: qsTr("Video \u00B7 click to download")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
                Button {
                    text: qsTr("\u2193")
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
            Label { text: "\uD83C\uDFB5"; font.pixelSize: Theme.fontSizeLg }
            Label {
                text: root.fileName + " \u00B7 " + formatBytes(root.fileSize)
                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Button { text: qsTr("\u2193"); onClicked: MatrixClient.downloadMedia(root.roomId, root.mxcUrl, root.fileName) }
        }
    }

    Component {
        id: fileComp
        RowLayout {
            spacing: Theme.spacingSm
            Label { text: "\uD83D\uDCC4"; font.pixelSize: Theme.fontSizeLg }
            ColumnLayout {
                Layout.fillWidth: true
                Label {
                    text: root.fileName
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: formatBytes(root.fileSize) + (root.mimeType.length > 0 ? " \u00B7 " + root.mimeType : "")
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
