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
// Media bubbles:
//   - Images  → inline preview via MatrixClient.requestMedia / mediaReady
//   - Videos  → inline player (MediaPlayer + VideoOutput)
//   - Audio / arbitrary files → tile with name, size, mime, Download button

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
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

    // Local file path for inline media (set when mediaReady fires).
    // Empty string = not yet fetched.
    property string mediaLocalPath: ""

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
                            case "system": return systemInlineComp
                            default: return textComp
                        }
                    }
                }
            }
        }

        // ── Spacer: fills remaining space so bubble doesn't stretch ──
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
        }
    }

    // ── Right-click context menu ──
    // Opens a Menu with: Reply, React (emoji picker), Save (file) / Copy
    // (text), Delete (own messages) / Hide (others).
    //
    // We attach the MouseArea to the bubble itself (not the whole Item) so
    // right-clicks outside the bubble (e.g. on the avatar or spacer) don't
    // accidentally trigger it.
    Menu {
        id: contextMenu
        modal: true
        dim: false

        // ── Reply ──
        // Always available for any non-system, non-encrypted message.
        MenuItem {
            text: qsTr("Reply")
            onTriggered: {
                MatrixClient.replyStarted(root.roomId, root.eventId, root.body)
            }
            enabled: root.kind !== "system" && root.kind !== "encrypted"
        }

        // ── React (emoji picker submenu) ──
        // Shows 8 common emoji as quick reactions; "More..." opens a
        // full emoji picker (a separate dialog). The selected emoji is
        // sent via MatrixClient.sendReaction.
        Menu {
            title: qsTr("React")
            Instantiator {
                model: ["\uD83D\uDC4D", "\uD83D\uDC4E", "\u2764\uFE0F", "\uD83D\uDE06",
                        "\uD83D\uDE22", "\uD83D\uDE0E", "\uD83C\uDF89", "\uD83D\uDE80"]
                MenuItem {
                    text: modelData
                    onTriggered: MatrixClient.sendReaction(root.roomId, root.eventId, modelData)
                }
                onObjectAdded: function(index, object) {
                    contextMenuReact.insertItem(index, object)
                }
                onObjectRemoved: function(index, object) {
                    contextMenuReact.removeItem(object)
                }
            }
            id: contextMenuReact
        }

        // ── Save (for files / images / videos) ──
        // Visible only for media messages. Triggers a fresh download via
        // MatrixClient.downloadMedia (which uses the E2EE-aware path).
        MenuItem {
            text: qsTr("Save")
            visible: root.kind === "image" || root.kind === "video"
                     || root.kind === "audio" || root.kind === "file"
            onTriggered: {
                if (root.mediaSourceJson.length > 0) {
                    MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
            }
        }

        // ── Copy (for text messages) ──
        // Copies the plain body to the clipboard via MatrixClient.copyText,
        // which emits textCopied(text) — main.qml handles the actual
        // clipboard write via a hidden TextEdit.
        MenuItem {
            text: qsTr("Copy")
            visible: root.kind === "text"
            onTriggered: MatrixClient.copyText(root.body)
        }

        // ── Delete (for own messages) / Hide for me (for others) ──
        // Matrix only lets the original sender redact — for other users'
        // messages we'd need server-side power level, which DMs typically
        // don't grant. So for non-own messages we show "Hide" and simply
        // remove the row from the local MessageModel (visual-only).
        MenuItem {
            text: root.isOwn ? qsTr("Delete") : qsTr("Hide for me")
            onTriggered: {
                if (root.isOwn) {
                    MatrixClient.redactEvent(root.roomId, root.eventId, "")
                } else {
                    // Hide for me — purely local. We tell the model to
                    // remove this event_id; it stays hidden until the
                    // next full reload (sync / room switch).
                    MessageModel.hideEvent(root.eventId)
                }
            }
        }
    }

    // Right-click handler — opens the context menu at the cursor position.
    // attachedToBubble ensures the menu only opens on right-click within
    // the bubble, not in the surrounding ListView whitespace.
    MouseArea {
        anchors.fill: chatRow
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            }
        }
    }

    // ── Inline media fetching ──
    // When this delegate becomes visible and has a mediaSourceJson, ask
    // the backend to fetch + cache the media. The backend emits
    // mediaReady(sourceJson, localPath) — we match on sourceJson.
    Component.onCompleted: {
        if (root.mediaSourceJson.length > 0) {
            // Check cache synchronously first — fast path.
            MatrixClient.requestMedia(root.mediaSourceJson, root.mimeType)
        }
    }

    // Listen for mediaReady signals matching our sourceJson.
    Connections {
        target: MatrixClient
        function onMediaReady(sourceJson, localPath) {
            if (sourceJson === root.mediaSourceJson) {
                root.mediaLocalPath = localPath
            }
        }
        function onMediaError(sourceJson, error) {
            if (sourceJson === root.mediaSourceJson) {
                console.log("MessageBubble: media fetch failed for " + sourceJson + ": " + error)
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

    // ── Image message ──
    // Inline preview with click-to-fullscreen. The image is fetched
    // asynchronously via MatrixClient.requestMedia / mediaReady. If the
    // fetch hasn't completed yet, we show a placeholder with the file
    // name + size.
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
            // Image preview (or placeholder while loading)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.mediaLocalPath.length > 0 ? img.status === Image.Ready ? img.implicitHeight : 240 : 80

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: root.mediaLocalPath.length > 0
                            ? "file://" + root.mediaLocalPath
                            : ""
                    asynchronous: true
                    visible: root.mediaLocalPath.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onDoubleClicked: {
                            // Open with system default app.
                            if (root.mediaLocalPath.length > 0) {
                                Qt.openUrlExternally("file://" + root.mediaLocalPath)
                            }
                        }
                    }
                }

                // Loading / error placeholder
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.mediaLocalPath.length === 0
                    spacing: 4
                    Label {
                        text: "\uD83D\uDDBC"  // 🖼
                        font.pixelSize: Theme.fontSizeLg
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: qsTr("Loading image\u2026")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: root.fileName + " \u00B7 " + formatBytes(root.fileSize)
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                        Layout.alignment: Qt.AlignHCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: 240
                    }
                }
            }
            // Download button + timestamp row
            RowLayout {
                Layout.fillWidth: true
                Label {
                    visible: Theme.showTimestamps && root.ts > 0
                    text: formatTime(root.ts)
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("\u2193 Save")
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
            }
        }
    }

    // ── Video message ──
    // Inline player with controls. The video is fetched asynchronously
    // via MatrixClient.requestMedia / mediaReady. While loading, we
    // show a placeholder with the file name + size.
    Component {
        id: videoComp
        ColumnLayout {
            spacing: 4
            // Caption
            Label {
                Layout.fillWidth: true
                visible: root.body.length > 0 && root.body !== root.fileName
                text: root.body
                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                font.pixelSize: Theme.fontSizeMd
                wrapMode: Text.Wrap
            }
            // Video player (or placeholder while loading)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 240

                // VideoOutput + MediaPlayer (Qt 5/6 multimedia)
                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    visible: root.mediaLocalPath.length > 0
                    fillMode: VideoOutput.PreserveAspectFit
                }
                MediaPlayer {
                    id: mediaPlayer
                    source: root.mediaLocalPath.length > 0
                            ? "file://" + root.mediaLocalPath
                            : ""
                    videoOutput: videoOut
                    // Don't auto-play — wait for user to click play.
                    autoPlay: false
                }

                // Controls overlay (play/pause + position slider)
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 4
                    visible: root.mediaLocalPath.length > 0
                    spacing: 4

                    Button {
                        text: mediaPlayer.playing ? qsTr("\u23F8") : qsTr("\u25B6")  // ⏸ / ▶
                        onClicked: {
                            if (mediaPlayer.playing) {
                                mediaPlayer.pause()
                            } else {
                                mediaPlayer.play()
                            }
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: mediaPlayer.duration > 0 ? mediaPlayer.duration : 1
                        value: mediaPlayer.position
                        onMoved: mediaPlayer.position = value
                    }
                    Label {
                        text: formatTimeShort(mediaPlayer.position) + " / " + formatTimeShort(mediaPlayer.duration)
                        color: Theme.sidebarFg
                        font.pixelSize: Theme.fontSizeXs
                    }
                }

                // Loading / error placeholder
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.mediaLocalPath.length === 0
                    spacing: 4
                    Label {
                        text: "\uD83C\uDFAC"  // 🎬
                        font.pixelSize: Theme.fontSizeLg
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: qsTr("Loading video\u2026")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Label {
                        text: root.fileName + " \u00B7 " + formatBytes(root.fileSize)
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeXs
                        Layout.alignment: Qt.AlignHCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: 240
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    visible: Theme.showTimestamps && root.ts > 0
                    text: formatTime(root.ts)
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("\u2193 Save")
                    enabled: root.mediaSourceJson.length > 0
                    onClicked: MatrixClient.downloadMedia(root.roomId, root.mediaSourceJson, root.fileName)
                }
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
    function formatTimeShort(ms) {
        if (ms <= 0 || isNaN(ms)) return "0:00"
        var s = Math.floor(ms / 1000)
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + ("0" + s).slice(-2)
    }
    function formatBytes(b) {
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }
}
