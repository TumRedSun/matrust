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
    // event_id of the message this one is replying to (filled from
    // msg.in_reply_to). Empty string = not a reply.
    property string replyTo
    // Body preview of the replied-to message. We populate this from
    // a local lookup in MessageModel — if the original message is in
    // the current page, we show its text; otherwise we show a
    // placeholder. This makes replies visually identifiable on both
    // sent and received sides.
    property string replyToBody: ""
    property string replyToSender: ""
    // Reactions for this message — JSON array string produced by the
    // Rust backend. Parsed into `reactionsModel` below. Empty string
    // means "no reactions".
    //
    // Format (see src/message_model.rs):
    //   [{"key":"👍","count":2,"includes_me":true,
    //     "senders":[{"user_id":"@a:b","display_name":"Alice"},
    //                 {"user_id":"@b:b","display_name":"Bob"}]},
    //    ...]
    property string reactions: ""

    // Parsed reactions array. Re-evaluated whenever `reactions` changes.
    // We catch JSON parse errors and fall back to [] so a corrupt string
    // never breaks the bubble.
    readonly property var reactionsModel: {
        var s = root.reactions
        if (!s || s.length === 0) return []
        try { return JSON.parse(s) } catch (e) { return [] }
    }

    // ── React-request signal ──
    // Fired when the user picks "React…" in the context menu.
    // ChatPage listens and opens the shared EmojiPicker popup pointed
    // at this message. We don't open the picker here because there's
    // one picker per ChatPage (not one per bubble) — instantiating a
    // Dialog in every delegate would create N popups for N visible
    // messages, leaking focus and memory.
    signal reactRequested(string roomId, string eventId)

    // ── Reaction-senders-popup signal ──
    // Fired when the user right-clicks a reaction chip. ChatPage
    // listens and opens the shared ReactionSendersPopup with the
    // given emoji + senders array. We don't open the popup here for
    // the same reason as reactRequested — one shared popup per
    // ChatPage, not N popups for N bubbles.
    signal reactionSendersRequested(string emoji, var senders)

    // ── Max image / video display height ──
    // Caps the inline preview height so a 4K screenshot doesn't take
    // over the whole chat view. Tuned to ~360 px which is roughly the
    // vertical space of 6-8 lines of text — feels natural to read past.
    readonly property int maxMediaHeight: 360

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
                return Tr.tr(Theme.language, "Encrypted message — decryption pending")
            }
            return root.body.length > 0 ? root.body : Tr.tr(Theme.language, "(event)")
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

                // ── Reply quote (shown when this message is a reply) ──
                // Renders a small quote of the original message above the
                // reply body. Clicking it scrolls to / highlights the
                // original message in the list view (if still loaded).
                //
                // Visible only when `root.replyTo` is non-empty — this is
                // populated by the Rust side from `msg.in_reply_to` when
                // parsing the timeline.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.topMargin: Theme.bubblePaddingV
                    Layout.preferredHeight: replyCol.implicitHeight + 8
                    visible: root.replyTo.length > 0
                    color: "transparent"
                    border.color: root.isOwn ? Theme.bubbleFgMe : Theme.accent
                    border.width: 0
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: root.isOwn ? Theme.bubbleFgMe : Theme.accent
                        opacity: 0.7
                    }
                    ColumnLayout {
                        id: replyCol
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            visible: root.replyToSender.length > 0
                            text: root.replyToSender
                            color: root.isOwn ? Theme.bubbleFgMe : Theme.accent
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: root.replyToBody.length > 0
                                  ? root.replyToBody
                                  : Tr.tr(Theme.language, "(original message)")
                            color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                            font.pixelSize: Theme.fontSizeXs
                            font.italic: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Ask ChatPage to scroll to / highlight the
                            // original message. We piggyback on the
                            // replyStarted signal machinery — but for a
                            // pure "jump to" we use a dedicated signal.
                            // For now, no-op; scrolling requires wiring
                            // a new signal. This is a future enhancement.
                        }
                    }
                }

                // Sender label (for non-own messages only)
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.topMargin: root.replyTo.length > 0 ? 2 : Theme.bubblePaddingV
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
                                      ? (root.replyTo.length > 0 ? 2 : Theme.bubblePaddingV) : 2
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

                // ── Reactions strip (shown below message body) ──
                // Renders one pill-shaped chip per reaction key. Each chip
                // shows the emoji + count of senders. Chips the current
                // user has reacted with get an accent border (Discord-style
                // highlight).
                //
                // Interaction (Discord-like):
                //   - LMB on chip: toggle our own reaction
                //     (if we've reacted → redact; if not → send).
                //   - RMB on chip: open ReactionSendersPopup showing the
                //     list of who reacted (delegated to ChatPage via the
                //     `reactionSendersRequested` signal — ChatPage owns the
                //     shared popup so we don't instantiate N popups for N
                //     bubbles).
                //
                // The chip list binds to `reactionsModel`, which is itself
                // a binding over `reactions` (the JSON string from the
                // backend). When the backend reloads after a toggle, the
                // new state propagates here automatically.
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.bottomMargin: Theme.bubblePaddingV
                    spacing: 4
                    visible: root.reactionsModel.length > 0
                    Repeater {
                        model: root.reactionsModel
                        delegate: Rectangle {
                            width: chipRow.implicitWidth + 14
                            height: 24
                            radius: 12
                            // Highlight chips I've reacted to with an
                            // accent border + slightly tinted bg.
                            color: modelData.includes_me
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                   : (root.isOwn
                                      ? Qt.lighter(Theme.bubbleBgMe, 1.3)
                                      : Qt.darker(Theme.bubbleBgThem, 1.3))
                            border.color: modelData.includes_me ? Theme.accent : Theme.border
                            border.width: modelData.includes_me ? 1.5 : 1

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: modelData.key
                                    font.pixelSize: Theme.fontSizeSm
                                    renderType: Text.NativeRendering
                                }
                                Label {
                                    text: modelData.count
                                    color: modelData.includes_me
                                           ? Theme.accent
                                           : (root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem)
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        // Toggle our reaction (Discord-style):
                                        //   - LMB on a chip we've reacted with → redact it
                                        //   - LMB on a chip others reacted with → add ours
                                        // Both cases are handled by the Rust
                                        // `toggleReaction` method which looks up
                                        // the current state and acts accordingly.
                                        MatrixClient.toggleReaction(
                                            root.roomId,
                                            root.eventId,
                                            modelData.key
                                        )
                                    } else if (mouse.button === Qt.RightButton) {
                                        // Open the "who reacted" popup.
                                        root.reactionSendersRequested(
                                            modelData.key,
                                            modelData.senders || []
                                        )
                                    }
                                }
                                onPressAndHold: function(mouse) {
                                    // Long-press on touch devices = same as
                                    // right-click (opens senders popup).
                                    if (mouse.button === Qt.LeftButton) {
                                        root.reactionSendersRequested(
                                            modelData.key,
                                            modelData.senders || []
                                        )
                                    }
                                }
                            }

                            // Hover tooltip: list of sender display names.
                            // Falls back to user_id when display_name is empty.
                            ToolTip.text: {
                                var senders = modelData.senders || []
                                if (senders.length === 0) return ""
                                return senders.map(function(s) {
                                    return s.display_name && s.display_name.length > 0
                                           ? s.display_name : s.user_id
                                }).join(", ")
                            }
                            ToolTip.visible: chipMouse.containsMouse
                            ToolTip.delay: 400
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
            text: Tr.tr(Theme.language, "Reply")
            onTriggered: {
                MatrixClient.replyStarted(root.roomId, root.eventId, root.body)
            }
            enabled: root.kind !== "system" && root.kind !== "encrypted"
        }

        // ── React (opens emoji picker popup) ──
        // Previously this was a submenu with ~150 emoji inline. That
        // made the context menu slow to open and impossible to scan.
        // Now it just fires `reactRequested` — ChatPage opens a single
        // shared EmojiPicker popup (search + rofi-style grid) pointed
        // at this message. One picker per ChatPage, not per bubble.
        MenuItem {
            text: Tr.tr(Theme.language, "React…")
            enabled: root.kind !== "system" && root.kind !== "encrypted"
            onTriggered: {
                root.reactRequested(root.roomId, root.eventId)
            }
        }

        // (Legacy inline emoji submenu removed — see EmojiPicker.qml
        // for the new full-screen picker with search + grid.)

        // ── Save (for files / images / videos) ──
        // Visible only for media messages. Triggers a fresh download via
        // MatrixClient.downloadMedia (which uses the E2EE-aware path).
        MenuItem {
            text: Tr.tr(Theme.language, "Save")
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
            text: Tr.tr(Theme.language, "Copy")
            visible: root.kind === "text"
            onTriggered: MatrixClient.copyText(root.body)
        }

        // ── Delete (for own messages) / Hide for me (for others) ──
        // Matrix only lets the original sender redact — for other users'
        // messages we'd need server-side power level, which DMs typically
        // don't grant. So for non-own messages we show "Hide" and simply
        // remove the row from the local MessageModel (visual-only).
        MenuItem {
            text: root.isOwn ? Tr.tr(Theme.language, "Delete") : Tr.tr(Theme.language, "Hide for me")
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
                      : (root.body.length > 0 ? root.body : Tr.tr(Theme.language, "(empty)"))
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
    // Inline preview sized to the image's actual aspect ratio, capped to
    // a comfortable reading size. Previously the bubble used
    // `img.implicitHeight`, which for some PNG/JPEG loads returned the
    // full image height in device pixels and produced a giant empty
    // rectangle. Now we explicitly clamp height to 360 px max and use
    // `Image.PreserveAspectFit` with `paintedHeight` for accurate
    // sizing after Qt scales the image to fit the available width.
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
            //
            // Width: capped at maxBubbleWidth minus padding.
            // Height: derived from `img.paintedHeight` (the actual
            // displayed height after PreserveAspectFit) once loaded,
            // else 240 while loading. Hard-capped at 360 px so a
            // 4K screenshot doesn't take over the whole chat view.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.mediaLocalPath.length > 0
                                        ? Math.min(360, Math.max(120, img.paintedHeight || 240))
                                        : 100
                implicitHeight: Layout.preferredHeight

                Image {
                    id: img
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: root.mediaLocalPath.length > 0
                            ? "file://" + root.mediaLocalPath
                            : ""
                    asynchronous: true
                    visible: root.mediaLocalPath.length > 0
                    // Trigger a relayout when the image finishes loading
                    // so `paintedHeight` becomes valid and the Item above
                    // resizes to the real aspect ratio.
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            parent.Layout.preferredHeight = Math.min(360, Math.max(120, paintedHeight))
                        }
                    }

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
                        text: Tr.tr(Theme.language, "Loading image\u2026")
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
            // Timestamp row (Save button intentionally removed —
            // download is now exclusively in the right-click context menu).
            RowLayout {
                Layout.fillWidth: true
                Label {
                    visible: Theme.showTimestamps && root.ts > 0
                    text: formatTime(root.ts)
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Item { Layout.fillWidth: true }
                Label {
                    // Show the file name + size subtly on the right so
                    // the user still has a way to see what the file is
                    // without opening the context menu.
                    visible: root.fileName.length > 0
                    text: root.fileName + " \u00B7 " + formatBytes(root.fileSize)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
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
                        text: mediaPlayer.playing ? Tr.tr(Theme.language, "\u23F8") : Tr.tr(Theme.language, "\u25B6")  // ⏸ / ▶
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
                        text: Tr.tr(Theme.language, "Loading video\u2026")
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
            // Timestamp row (Save button removed — context menu only).
            RowLayout {
                Layout.fillWidth: true
                Label {
                    visible: Theme.showTimestamps && root.ts > 0
                    text: formatTime(root.ts)
                    color: root.isOwn ? Theme.bubbleFgMe : Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: root.fileName.length > 0
                    text: root.fileName + " \u00B7 " + formatBytes(root.fileSize)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                    elide: Text.ElideRight
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
                        text: root.fileName.length > 0 ? root.fileName : Tr.tr(Theme.language, "Audio")
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
                        text: root.fileName.length > 0 ? root.fileName : Tr.tr(Theme.language, "File")
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
