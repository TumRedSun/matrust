// ChatPage.qml — main chat view: header, message list, composer.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    id: chatPageRoot
    color: Theme.windowBg
    property string roomId: ""

    // Emitted when the user presses the back arrow — the parent
    // (main.qml) should clear activeRoomId.
    signal goBack()

    // Resolve the display name for the current room from RoomModel.
    // This is updated reactively when RoomModel changes (see Connections below).
    property string roomDisplayName: ""

    // Pending attachments — JS array of objects:
    //   {path, name, size, mime, kind}
    // where kind is "image" | "video" | "audio" | "file" (inferred from mime).
    // `name` is the user-editable display name (defaults to the file's
    // basename; the pencil button lets the user rename it without
    // touching the original file on disk).
    // `size` is filled in via a synchronous stat call (listDirectory on
    // the parent dir) so the composer preview can show "2.4 MB".
    // When the user presses Enter (or clicks Send), all attachments are
    // uploaded + sent, followed by the text (if any) as a separate message.
    property var pendingAttachments: []
    // When set, the composer is replying to this event_id (set via the
    // message context menu → Reply). Cleared on send or cancel.
    property string replyToEventId: ""
    property string replyToBody: ""

    // Helper to look up room name from RoomModel.
    // Role numbers: USER_ROLE=256, so room_id=256, name=257.
    function lookupRoomName() {
        if (roomId.length === 0) {
            roomDisplayName = ""
            return
        }
        for (var j = 0; j < RoomModel.count; j++) {
            var ix = RoomModel.index(j, 0)
            var rid = RoomModel.data(ix, 256).toString()   // room_id role (USER_ROLE + 0)
            if (rid === roomId) {
                var name = RoomModel.data(ix, 257).toString() // name role (USER_ROLE + 1)
                console.log("ChatPage: found room name=\"" + name + "\" for roomId=" + roomId)
                roomDisplayName = name.length > 0 ? name : roomId
                return
            }
        }
        console.log("ChatPage: room not found in RoomModel, roomId=" + roomId + " count=" + RoomModel.count)
        roomDisplayName = roomId
    }

    // Infer the "kind" of a file from its MIME type or extension.
    // Used to choose between image / video / audio / file AttachmentInfo.
    function inferKind(path, mime) {
        var p = path.toLowerCase()
        var m = mime.toLowerCase()
        if (m.indexOf("image/") === 0 || /\.(png|jpe?g|gif|webp|svg|bmp|heic|heif|tiff?|avif)$/.test(p)) {
            return "image"
        }
        if (m.indexOf("video/") === 0 || /\.(mp4|webm|mkv|mov|avi|mpg|mpeg|m4v|flv|wmv|3gp)$/.test(p)) {
            return "video"
        }
        if (m.indexOf("audio/") === 0 || /\.(mp3|wav|ogg|flac|aac|m4a|opus|wma|aiff?)$/.test(p)) {
            return "audio"
        }
        return "file"
    }

    // Format a byte count as a human-readable string ("2.4 MB", etc.).
    function formatBytes(b) {
        if (b < 1024) return b + " B"
        if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
        if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
        return (b / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    // Synchronously stat a file by path. Returns {size: number} or {size: 0}
    // on error. We do this by calling listDirectory on the parent folder
    // and matching the name — listDirectory itself does a stat-per-entry
    // in Rust so we get the real size from metadata, not 0.
    function statFile(path) {
        try {
            var slash = path.lastIndexOf("/")
            var parent = slash > 0 ? path.substring(0, slash) : "/"
            var name = slash >= 0 ? path.substring(slash + 1) : path
            var json = MatrixClient.listDirectory(parent, true)
            var entries = JSON.parse(json)
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].name === name && !entries[i].is_dir) {
                    return {size: entries[i].size}
                }
            }
        } catch (e) {
            console.log("statFile failed: " + e)
        }
        return {size: 0}
    }

    // Add a file path to the pending attachments list.
    function addAttachment(path) {
        // Strip file:// prefix if present
        if (path.startsWith("file://")) path = path.substring(7)
        // Decode percent-encoded path (fileDialog URLs sometimes are)
        try { path = decodeURIComponent(path) } catch (e) {}
        // Derive display name from path
        var name = path
        var slash = path.lastIndexOf("/")
        if (slash >= 0) name = path.substring(slash + 1)
        // Stat the file to get its real size. Without this the composer
        // preview shows "0 B" even though the file is non-empty — same bug
        // as the timeline one, just on the local side.
        var info = statFile(path)
        var mime = ""  // empty → send_attachment will infer via mime_guess
        var kind = inferKind(path, mime)
        var copy = pendingAttachments.slice()
        copy.push({path: path, name: name, size: info.size, mime: mime, kind: kind})
        pendingAttachments = copy
    }

    // Remove an attachment by index.
    function removeAttachment(index) {
        var copy = pendingAttachments.slice()
        copy.splice(index, 1)
        pendingAttachments = copy
    }

    // Rename an attachment's display name (does NOT modify the file on disk).
    function renameAttachment(index, newName) {
        if (newName.trim().length === 0) return
        var copy = pendingAttachments.slice()
        if (index < 0 || index >= copy.length) return
        copy[index] = JSON.parse(JSON.stringify(copy[index]))
        copy[index].name = newName.trim()
        pendingAttachments = copy
    }

    // Begin composing a reply to the given event_id.
    function startReply(eventId, originalBody) {
        replyToEventId = eventId
        replyToBody = originalBody
        composer.forceActiveFocus()
    }

    // Cancel an in-progress reply.
    function cancelReply() {
        replyToEventId = ""
        replyToBody = ""
    }

    // Look up a replied-to message by event_id in the current
    // MessageModel. If found, store its body + sender so the
    // MessageBubble can render a reply quote above the reply body.
    //
    // Used by MessageBubble.Component.onCompleted when its `replyTo`
    // property is set (from model.reply_to). We scan MessageModel
    // role-by-role because QAbstractListModel doesn't expose a
    // "find by id" API — the visible window is ~50 items so this is
    // cheap.
    //
    // Sets two properties on the passed `bubble` object: replyToBody
    // and replyToSender. Returns nothing — caller passes the bubble
    // instance and we mutate it directly.
    function lookupReplyTarget(targetEventId) {
        if (targetEventId.length === 0) return
        // Role numbers — see MessageEntry.names() in src/message_model.rs:
        //   event_id        = USER_ROLE + 0  = 256
        //   sender          = USER_ROLE + 1  = 257
        //   sender_display  = USER_ROLE + 2  = 258
        //   body            = USER_ROLE + 4  = 260
        //   kind            = USER_ROLE + 8  = 264
        //   file_name       = USER_ROLE + 11 = 267
        var n = MessageModel.count
        for (var i = 0; i < n; i++) {
            var ix = MessageModel.index(i, 0)
            var eid = MessageModel.data(ix, 256).toString()
            if (eid === targetEventId) {
                var body = MessageModel.data(ix, 260).toString()
                var sender = MessageModel.data(ix, 258).toString()
                if (sender.length === 0) {
                    sender = MessageModel.data(ix, 257).toString()
                }
                var kind = MessageModel.data(ix, 264).toString()
                var fname = MessageModel.data(ix, 267).toString()
                // For media messages, the body is usually the file name
                // (which is not useful as a quote). Substitute a kind
                // label so the quote shows "📷 Photo" instead of
                // "Screenshot_2025-08-19.png".
                if (kind === "image") body = Tr.tr(Theme.language, "\uD83D\uDDBC Photo")
                else if (kind === "video") body = Tr.tr(Theme.language, "\uD83C\uDFAC Video")
                else if (kind === "audio") body = Tr.tr(Theme.language, "\uD83C\uDFB5 Audio")
                else if (kind === "file") body = Tr.tr(Theme.language, "\uD83D\uDCC4 File: ") + fname
                return { body: body, sender: sender }
            }
        }
        // Not found — original may be outside the loaded 50-item window.
        // Return empty values; the QML will show "(original message)".
        return { body: "", sender: "" }
    }

    // Send all pending attachments + the current text, then clear.
    function sendAll() {
        if (MatrixClient.offline) return
        if (roomId.length === 0) return
        var hasText = composer.text.trim().length > 0
        var hasAttachments = pendingAttachments.length > 0
        var hasReply = replyToEventId.length > 0
        if (!hasText && !hasAttachments && !hasReply) return

        // If we're replying, send the text as a reply first (so the reply
        // relationship is attached). If there's no text but we're replying
        // with attachments only, we send attachments normally (Matrix
        // doesn't support attaching a reply relation to m.image/m.file in
        // a way that other clients render consistently).
        if (hasReply && hasText) {
            MatrixClient.sendReply(roomId, replyToEventId, composer.text)
        } else if (hasText) {
            MatrixClient.sendText(roomId, composer.text)
        }

        // Send attachments (each as its own message event — Matrix
        // doesn't support multi-file events, so each file becomes a
        // separate m.image / m.video / m.file message).
        for (var i = 0; i < pendingAttachments.length; i++) {
            var a = pendingAttachments[i]
            // Pass the (possibly renamed) display name so the receiver
            // sees "share.png" instead of "Screenshot_2025-08-19.png".
            MatrixClient.sendFile(roomId, a.path, a.name, a.mime, a.kind)
        }

        composer.text = ""
        pendingAttachments = []
        replyToEventId = ""
        replyToBody = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.sidebarBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMd
                anchors.rightMargin: Theme.paddingMd
                spacing: Theme.spacingSm

                // Back button — simply deselects the room (goes back).
                ToolButton {
                    text: "\u2190"  // ← back arrow
                    font.pixelSize: Theme.fontSizeMd
                    visible: roomId.length > 0
                    enabled: roomId.length > 0
                    onClicked: {
                        chatPageRoot.goBack()
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: roomId.length > 0
                          ? roomDisplayName
                          : Tr.tr(Theme.language, "No room selected")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    elide: Text.ElideRight
                }
                // Status indicator removed: the "Ready" label was confusing
                // and added noise. Offline state is still visible via the
                // composer's red placeholder text and disabled send button.
            }
        }

        // ── Messages ──
        // Only show the message list when a room is actually selected.
        // When no room is selected, show a placeholder instead.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Placeholder when no room selected
            Label {
                anchors.centerIn: parent
                visible: chatPageRoot.roomId.length === 0
                text: Tr.tr(Theme.language, "Select a conversation")
                color: Theme.muted
                font.pixelSize: Theme.fontSizeLg
            }

            // Message list (only visible when a room is selected)
            ScrollView {
                visible: chatPageRoot.roomId.length > 0
                anchors.fill: parent
                clip: true

                ListView {
                    id: messagesView
                    model: MessageModel
                    spacing: 8
                    verticalLayoutDirection: ListView.BottomToTop
                    cacheBuffer: 4000

                    delegate: MessageBubble {
                        width: messagesView.width - Theme.paddingMd * 2
                        anchors.horizontalCenter: undefined
                        eventId: model.event_id
                        sender: model.sender_display.length > 0 ? model.sender_display : model.sender
                        avatarUrl: model.avatar_url
                        body: model.body
                        bodyHtml: model.body_html
                        ts: model.ts
                        isOwn: model.is_own
                        kind: model.kind
                        mxcUrl: model.mxc_url
                        mediaSourceJson: model.media_source_json
                        fileName: model.file_name
                        fileSize: model.file_size
                        mimeType: model.mime_type
                        replyTo: model.reply_to
                        // Pass through the JSON reactions string from the
                        // backend. MessageBubble parses it into a model
                        // and renders chips with count + LMB toggle +
                        // RMB popup behavior.
                        reactions: model.reactions || ""
                        roomId: chatPageRoot.roomId

                        // ── Reply quote lookup ──
                        // When the message has `reply_to` set, look up
                        // the original message in MessageModel so we can
                        // show a preview of the replied-to body + sender.
                        // Done in Component.onCompleted (one-shot, when
                        // the delegate is created) — cheap O(n) scan
                        // over the visible window of ~50 messages.
                        Component.onCompleted: {
                            if (replyTo.length > 0) {
                                var r = chatPageRoot.lookupReplyTarget(replyTo)
                                if (r) {
                                    replyToBody = r.body
                                    replyToSender = r.sender
                                }
                            }
                        }

                        // ── React-request handler ──
                        // When the user picks "React…" in the bubble's
                        // context menu, the bubble emits reactRequested.
                        // We point the shared EmojiPicker at this message
                        // and open it. The picker calls
                        // MatrixClient.sendReaction() on the chosen emoji.
                        onReactRequested: function(roomId, eventId) {
                            emojiPicker.roomId = roomId
                            emojiPicker.eventId = eventId
                            emojiPicker.open()
                        }

                        // ── Reaction-senders handler ──
                        // When the user right-clicks a reaction chip,
                        // the bubble emits reactionSendersRequested with
                        // the emoji + senders array. We point the shared
                        // ReactionSendersPopup at this and open it.
                        onReactionSendersRequested: function(emoji, senders) {
                            reactionSendersPopup.emoji = emoji
                            reactionSendersPopup.senders = senders
                            reactionSendersPopup.open()
                        }
                    }
                }
            }
        }

        // ── Reply banner (shown when composing a reply) ──
        // Visible only when replyToEventId is set (set via the message
        // context menu → Reply). Clicking ✕ cancels the reply.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: replyToEventId.length > 0 ? 36 : 0
            color: Theme.sidebarBg
            visible: replyToEventId.length > 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingMd
                anchors.rightMargin: Theme.paddingMd
                spacing: Theme.spacingSm

                Rectangle {
                    width: 3
                    Layout.fillHeight: true
                    color: Theme.accent
                }
                Label {
                    text: Tr.tr(Theme.language, "Replying to:")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeXs
                }
                Label {
                    Layout.fillWidth: true
                    text: chatPageRoot.replyToBody.length > 0
                          ? chatPageRoot.replyToBody
                          : Tr.tr(Theme.language, "(original message)")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeXs
                    font.italic: true
                    elide: Text.ElideRight
                }
                Button {
                    text: "\u2715"  // ✕
                    background: Rectangle { color: "transparent" }
                    contentItem: Label {
                        text: parent.text
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSm
                    }
                    onClicked: chatPageRoot.cancelReply()
                }
            }
        }

        // ── Pending attachments strip (Discord-style) ──
        // Visible only when there are pending attachments.
        //
        // Each attachment chip shows:
        //   - A thumbnail preview for images and videos (loaded directly
        //     from the local file path via file:// — no upload needed).
        //   - A kind icon for audio / generic files.
        //   - The display name (editable via the pencil button).
        //   - The file size (fetched at add-time via listDirectory).
        //   - Two action buttons: ✏ (rename) and ✕ (remove).
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: pendingAttachments.length > 0 ? 96 : 0
            color: Theme.sidebarBg
            visible: pendingAttachments.length > 0

            ScrollView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true

                ListView {
                    id: attachmentsList
                    model: chatPageRoot.pendingAttachments
                    orientation: ListView.Horizontal
                    spacing: 6

                    delegate: Rectangle {
                        width: 240
                        height: attachmentsList.height - 8
                        anchors.verticalCenter: undefined
                        color: Theme.bubbleBgMe
                        radius: Theme.radiusSm
                        border.color: Theme.border
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            // Thumbnail / kind icon
                            Item {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64

                                // Image thumbnail (for image kinds)
                                Image {
                                    anchors.fill: parent
                                    source: modelData.kind === "image"
                                            ? "file://" + modelData.path
                                            : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: modelData.kind === "image" && status === Image.Ready
                                    cache: false
                                }

                                // Video frame thumbnail — Qt 5.15's
                                // MediaPlayer doesn't reliably produce a
                                // poster frame without playing, so we use
                                // the kind icon as a placeholder. The
                                // actual video plays inline once sent.
                                // (A future improvement could use ffmpeg
                                // to extract a frame.)
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.kind === "video" ? "\uD83C\uDFAC"
                                          : modelData.kind === "audio" ? "\uD83C\uDFB5"
                                          : "\uD83D\uDCC4"
                                    font.pixelSize: 28
                                    visible: modelData.kind !== "image"
                                }

                                // Subtle border around thumbnail
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: Theme.border
                                    border.width: 1
                                    radius: Theme.radiusSm
                                }
                            }

                            // Name + size + kind
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    text: modelData.name
                                    color: Theme.bubbleFgMe
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: chatPageRoot.formatBytes(modelData.size || 0)
                                          + " \u00B7 " + modelData.kind
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    textFormat: Text.PlainText
                                }
                            }

                            // Action buttons
                            ColumnLayout {
                                spacing: 2
                                Button {
                                    text: "\u270F"  // ✏ pencil
                                    background: Rectangle {
                                        color: parent.hovered ? Theme.accent : "transparent"
                                        radius: Theme.radiusSm
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: parent.hovered ? Theme.accentFg : Theme.bubbleFgMe
                                        font.pixelSize: Theme.fontSizeSm
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    ToolTip.text: Tr.tr(Theme.language, "Rename this file (does not modify the original)")
                                    ToolTip.visible: hovered
                                    onClicked: {
                                        renameDialog.attachmentIndex = index
                                        renameDialog.currentName = modelData.name
                                        renameDialog.open()
                                    }
                                }
                                Button {
                                    text: "\u2715"  // ✕
                                    background: Rectangle {
                                        color: parent.hovered ? Theme.accent : "transparent"
                                        radius: Theme.radiusSm
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: parent.hovered ? Theme.accentFg : Theme.bubbleFgMe
                                        font.pixelSize: Theme.fontSizeSm
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    ToolTip.text: Tr.tr(Theme.language, "Remove this attachment")
                                    ToolTip.visible: hovered
                                    onClicked: chatPageRoot.removeAttachment(index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Composer ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Theme.sidebarBg
            visible: chatPageRoot.roomId.length > 0

            // ── Drag & Drop file upload ──
            // Whole composer area accepts dropped files. Each dropped URL
            // is added to pendingAttachments via addAttachment(), so the
            // user sees the same preview strip as if they'd clicked the
            // 📁 button — then sends the batch with Enter / Send.
            //
            // We accept "text/uri-list" (the standard MIME for file drags
            // from file managers) and reject everything else (so the user
            // doesn't accidentally drop text selections, etc).
            //
            // A subtle highlight border appears while a drag is hovering
            // to give visual feedback that the drop will be accepted.
            Rectangle {
                id: dropHighlight
                anchors.fill: parent
                color: "transparent"
                border.color: Theme.accent
                border.width: 2
                radius: Theme.radiusSm
                visible: dropArea.containsDrag
                z: 5
            }
            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: function(drop) {
                    // `drop.urls` is a list of QUrl — toString() gives
                    // "file:///path/to/file". We strip the "file://" prefix.
                    var added = 0
                    for (var i = 0; i < drop.urls.length; i++) {
                        var url = drop.urls[i].toString()
                        if (url.indexOf("file://") === 0) {
                            // Qt encodes the path — decode it back to a
                            // filesystem path before passing to Rust.
                            var path = decodeURIComponent(url.substring(7))
                            // On Linux the path is absolute and starts
                            // with "/". On Windows it'd be "C:/..." but
                            // this client is Linux-only for now.
                            chatPageRoot.addAttachment(path)
                            added++
                        }
                    }
                    if (added > 0) {
                        drop.acceptProposedAction()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingSm
                anchors.rightMargin: Theme.paddingSm
                spacing: Theme.spacingSm

                // Single universal attach button (replaces 3 buttons).
                // Clicking it opens the custom FileBrowserDialog which
                // supports multi-file selection + hidden files.
                Button {
                    text: Tr.tr(Theme.language, "\uD83D\uDCC1")  // 📁
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: fileBrowser.open()
                    enabled: roomId.length > 0 && !MatrixClient.offline
                    ToolTip.text: Tr.tr(Theme.language, "Attach files (multiple selection supported)")
                    ToolTip.visible: hovered
                }

                // Emoji insert button — opens the emoji picker in
                // "insert" mode. Picking an emoji inserts it as text at
                // the composer's cursor position (Discord-style), NOT as
                // a reaction. Reactions are sent via right-click on a
                // message bubble.
                Button {
                    text: "\uD83D\uDE00"  // 😀
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: emojiInserter.open()
                    enabled: roomId.length > 0 && !MatrixClient.offline
                    ToolTip.text: Tr.tr(Theme.language, "Insert emoji into message")
                    ToolTip.visible: hovered
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: composer
                        placeholderText: MatrixClient.offline
                                               ? Tr.tr(Theme.language, "Offline \u2014 messages cannot be sent")
                                               : (pendingAttachments.length > 0
                                                  ? Tr.tr(Theme.language, "Add a caption (optional) and press Enter to send\u2026")
                                                  : Tr.tr(Theme.language, "Type a message\u2026"))
                        placeholderTextColor: MatrixClient.offline ? Theme.accent : Theme.muted
                        color: MatrixClient.offline ? Theme.muted : Theme.sidebarFg
                        wrapMode: TextArea.Wrap
                        background: Rectangle { color: "transparent" }
                        readOnly: MatrixClient.offline
                        Keys.onReturnPressed: function(event) {
                            if (MatrixClient.offline) return
                            if (event.modifiers & Qt.ControlModifier) {
                                composer.append("\n")
                            } else {
                                event.accepted = true
                                chatPageRoot.sendAll()
                            }
                        }
                    }
                }

                // Send button — up-arrow icon (Discord/Telegram style).
                // Icon-only to save horizontal space and avoid translation
                // width issues ("Send" vs "Отправить" had different widths).
                Button {
                    text: "\u2191"  // ↑
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    enabled: roomId.length > 0
                             && (composer.text.trim().length > 0 || pendingAttachments.length > 0)
                             && !MatrixClient.offline
                    background: Rectangle {
                        color: parent.enabled ? Theme.accent : Theme.muted
                        radius: Theme.radiusSm
                    }
                    contentItem: Label {
                        text: parent.text
                        color: Theme.accentFg
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        horizontalAlignment: Qt.AlignHCenter
                        verticalAlignment: Qt.AlignVCenter
                    }
                    onClicked: chatPageRoot.sendAll()
                    ToolTip.text: Tr.tr(Theme.language, "Send")
                    ToolTip.visible: hovered
                }
            }
        }
    }

    // Custom file browser (multi-select + hidden files support).
    // The stock QtQuick.Dialogs FileDialog doesn't expose a show-hidden
    // toggle, and on most Linux desktops the native dialog hides dotfiles.
    FileBrowserDialog {
        id: fileBrowser
        onFilesSelected: function(paths) {
            for (var i = 0; i < paths.length; i++) {
                chatPageRoot.addAttachment(paths[i])
            }
        }
    }

    // ── Rename dialog ──
    // Lets the user rename the display name of a pending attachment
    // without touching the original file on disk. Pre-fills with the
    // current name and selects it for easy overwrite.
    Dialog {
        id: renameDialog
        modal: true
        title: Tr.tr(Theme.language, "Rename attachment")
        width: 400
        standardButtons: Dialog.Ok | Dialog.Cancel
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property int attachmentIndex: -1
        property string currentName: ""

        background: Rectangle {
            color: Theme.windowBg
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusMd
        }

        onOpened: {
            renameInput.text = currentName
            renameInput.selectAll()
            renameInput.forceActiveFocus()
        }
        onAccepted: {
            if (attachmentIndex >= 0 && renameInput.text.trim().length > 0) {
                chatPageRoot.renameAttachment(attachmentIndex, renameInput.text)
            }
        }

        contentItem: ColumnLayout {
            spacing: 8
            Label {
                text: Tr.tr(Theme.language, "New name (the original file is not modified):")
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeSm
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            TextField {
                id: renameInput
                Layout.fillWidth: true
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeMd
                background: Rectangle {
                    color: Theme.sidebarBg
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusSm
                }
                Keys.onReturnPressed: {
                    renameDialog.accept()
                }
            }
        }
    }

    // Listen for replyStarted from the message context menu (in MessageBubble).
    // We can't directly call ChatPage.startReply from a nested delegate
    // because the delegates don't have a reference to the ChatPage, so we
    // route through a global signal on MatrixClient.
    Connections {
        target: MatrixClient
        function onReplyStarted(rid, event_id, body) {
            if (rid === chatPageRoot.roomId) {
                chatPageRoot.startReply(event_id, body)
            }
        }
    }

    Connections {
        target: MessageModel
        function onHistoryLoaded(rid) {
            if (rid === roomId) {
                // If we just switched to this room (no saved scroll
                // position), pin to the bottom so the newest message
                // is visible. Otherwise, the syncDone handler in
                // ChatPage already restored scroll via the Timer.
                if (!restoreScrollTimer.running) {
                    messagesView.positionViewAtBeginning()
                }
            }
        }
    }

    // Reactively update room display name when RoomModel changes
    // (count_changed signal is emitted by RoomModel.apply_entries)
    Connections {
        target: RoomModel
        function onCountChanged() {
            lookupRoomName()
        }
    }

    // After each sync cycle, reload messages for the currently open
    // room so new incoming messages appear in real time.
    //
    // ── Sync-triggered reload with debounce ──
    // The Rust sync loop fires `syncDone` after every poll cycle (every
    // ~30s normally, but more often when messages arrive). Each fires
    // `loadRoomMessages` which triggers `beginResetModel` on the Qt
    // side — that's what caused the visible flicker ("messages disappear
    // for a frame then reappear").
    //
    // We debounce: collapse a burst of syncDone signals into a single
    // reload that fires 400ms after the last one. This means a single
    // arriving message produces one smooth reload instead of a stutter.
    //
    // We also save scroll state at debounce time (not at signal time)
    // so the saved Y reflects the latest user position.
    Connections {
        target: MatrixClient
        function onSyncDone(payload) {
            if (chatPageRoot.roomId.length === 0) return
            // Coalesce: restart the debounce timer. If a reload is
            // already pending, it gets pushed back another 400ms —
            // so a burst of 3 syncs in 1s produces only 1 reload.
            syncReloadTimer.start()
        }
    }

    Timer {
        id: syncReloadTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (chatPageRoot.roomId.length === 0) return
            // Save scroll state. For BottomToTop layout:
            //   atYBeginning == true  → user is at the bottom (newest)
            //   atYBeginning == false → user scrolled up to read history
            var wasAtBottom = messagesView.atYBeginning
            var savedY = messagesView.contentY
            MatrixClient.loadRoomMessages(chatPageRoot.roomId)
            // Restore after the model resets (onHistoryLoaded handles
            // re-positioning to the bottom; for the "scrolled up" case
            // we re-apply savedY here via a Timer to let the model
            // settle first).
            if (!wasAtBottom) {
                restoreScrollTimer.savedY = savedY
                restoreScrollTimer.start()
            }
        }
    }

    // Used to restore scroll position after a sync-triggered reload
    // when the user was NOT at the bottom.
    Timer {
        id: restoreScrollTimer
        property real savedY: 0
        interval: 50
        repeat: false
        onTriggered: {
            // Clamp to valid range. contentY can be negative for
            // BottomToTop layout when scrolled up.
            var minY = messagesView.originY
            var maxY = messagesView.originY + messagesView.contentHeight - messagesView.height
            var clamped = Math.max(minY, Math.min(savedY, maxY))
            messagesView.contentY = clamped
        }
    }

    // Also update when roomId changes
    onRoomIdChanged: {
        lookupRoomName()
        // Explicitly load messages for the newly selected room.
        // This is the ONLY place we trigger loadRoomMessages from
        // ChatPage.qml — every other path (sync, room name lookup)
        // must NOT trigger a reload to avoid the duplicate-load storm
        // we saw in the logs.
        if (roomId.length > 0) {
            MatrixClient.loadRoomMessages(roomId)
        }
    }

    // ── Shared emoji picker popup ──
    // One instance per ChatPage. MessageBubble delegates emit
    // `reactRequested(roomId, eventId)` when the user picks "React…"
    // in their context menu; the handler above sets this picker's
    // target and opens it. The picker sends the reaction via
    // MatrixClient.sendReaction() when the user picks an emoji.
    //
    // Kept here (not inside MessageBubble) so we don't instantiate
    // N popups for N visible messages — that would leak focus and
    // memory. Dialog manages its own overlay/parent, so we don't set
    // `parent` here — `parent: Overlay.overlay` inside the picker
    // resolves to the window's overlay layer.
    EmojiPicker {
        id: emojiPicker
        mode: "reaction"
        roomId: chatPageRoot.roomId
        // eventId is set by the onReactRequested handler above
        // before calling open().
    }

    // ── Emoji inserter (insert-as-text mode) ──
    // Separate instance from `emojiPicker` (which is in reaction mode).
    // Opens when the user clicks the 😀 button next to the file attach
    // button in the composer. Picking an emoji inserts it into the
    // composer at the cursor position (Discord-style).
    EmojiPicker {
        id: emojiInserter
        mode: "insert"
        onEmojiPicked: function(emoji) {
            // Insert at cursor position; if the composer doesn't have
            // focus (e.g. user clicked the 😀 button which then stole
            // focus to the search field), fall back to appending.
            composer.forceActiveFocus()
            var pos = composer.cursorPosition > 0 ? composer.cursorPosition : composer.length
            composer.insert(pos, emoji)
        }
    }

    // ── Shared reaction-senders popup ──
    // One instance per ChatPage. MessageBubble delegates emit
    // `reactionSendersRequested(emoji, senders)` when the user right-
    // clicks a reaction chip; the handler above sets the popup's emoji
    // + senders and opens it.
    //
    // Same rationale as emojiPicker: shared, not per-bubble.
    ReactionSendersPopup {
        id: reactionSendersPopup
    }
}
