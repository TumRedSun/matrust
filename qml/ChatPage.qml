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

    // Pending attachments — JS array of objects: {path, name, size, mime, kind}
    // where kind is "image" | "video" | "audio" | "file" (inferred from mime).
    // When the user presses Enter (or clicks Send), all attachments are
    // uploaded + sent, followed by the text (if any) as a separate message.
    property var pendingAttachments: []

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
        // Get file size via listDirectory parent + name lookup — too expensive.
        // Instead, just store the path and infer mime from extension.
        var mime = ""  // empty → send_attachment will infer via mime_guess
        var kind = inferKind(path, mime)
        var copy = pendingAttachments.slice()
        copy.push({path: path, name: name, mime: mime, kind: kind})
        pendingAttachments = copy
    }

    // Remove an attachment by index.
    function removeAttachment(index) {
        var copy = pendingAttachments.slice()
        copy.splice(index, 1)
        pendingAttachments = copy
    }

    // Send all pending attachments + the current text, then clear.
    function sendAll() {
        if (MatrixClient.offline) return
        if (roomId.length === 0) return
        var hasText = composer.text.trim().length > 0
        var hasAttachments = pendingAttachments.length > 0
        if (!hasText && !hasAttachments) return

        // Send attachments first (each as its own message event — Matrix
        // doesn't support multi-file events, so each file becomes a
        // separate m.image / m.video / m.file message).
        for (var i = 0; i < pendingAttachments.length; i++) {
            var a = pendingAttachments[i]
            MatrixClient.sendFile(roomId, a.path, a.mime, a.kind)
        }
        // Then send the text (if any) as a separate m.message event.
        // Doing text last so the attachments appear above the caption in
        // the timeline (which is the natural reading order).
        if (hasText) {
            MatrixClient.sendText(roomId, composer.text)
        }
        composer.text = ""
        pendingAttachments = []
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
                          : qsTr("No room selected")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    text: MatrixClient.offline
                          ? qsTr("Offline")
                          : (MatrixClient.busy ? qsTr("Syncing\u2026") : qsTr("Ready"))
                    color: MatrixClient.offline ? Theme.accent : Theme.muted
                    font.pixelSize: Theme.fontSizeSm
                }
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
                text: qsTr("Select a conversation")
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
                        roomId: chatPageRoot.roomId
                    }
                }
            }
        }

        // ── Pending attachments strip (Discord-style) ──
        // Visible only when there are pending attachments.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: pendingAttachments.length > 0 ? 72 : 0
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
                    spacing: 4

                    delegate: Rectangle {
                        width: 200
                        height: attachmentsList.height - 8
                        anchors.verticalCenter: undefined
                        color: Theme.bubbleBgMe
                        radius: Theme.radiusSm

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Label {
                                text: modelData.kind === "image" ? "\uD83D\uDDBC"
                                      : modelData.kind === "video" ? "\uD83C\uDFAC"
                                      : modelData.kind === "audio" ? "\uD83C\uDFB5"
                                      : "\uD83D\uDCC4"
                                font.pixelSize: Theme.fontSizeLg
                            }
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
                                    text: modelData.kind
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    textFormat: Text.PlainText
                                }
                            }
                            Button {
                                text: "\u2715"  // ✕
                                background: Rectangle { color: "transparent" }
                                font.pixelSize: Theme.fontSizeSm
                                onClicked: chatPageRoot.removeAttachment(index)
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

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingSm
                anchors.rightMargin: Theme.paddingSm
                spacing: Theme.spacingSm

                // Single universal attach button (replaces 3 buttons).
                // Clicking it opens the custom FileBrowserDialog which
                // supports multi-file selection + hidden files.
                Button {
                    text: qsTr("\uD83D\uDCC1")  // 📁
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: fileBrowser.open()
                    enabled: roomId.length > 0 && !MatrixClient.offline
                    ToolTip.text: qsTr("Attach files (multiple selection supported)")
                    ToolTip.visible: hovered
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: composer
                        placeholderText: MatrixClient.offline
                                               ? qsTr("Offline \u2014 messages cannot be sent")
                                               : (pendingAttachments.length > 0
                                                  ? qsTr("Add a caption (optional) and press Enter to send\u2026")
                                                  : qsTr("Type a message\u2026"))
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

                Button {
                    text: qsTr("Send")
                    enabled: roomId.length > 0
                             && (composer.text.trim().length > 0 || pendingAttachments.length > 0)
                             && !MatrixClient.offline
                    background: Rectangle { color: parent.enabled ? Theme.accent : Theme.muted; radius: Theme.radiusSm }
                    contentItem: Label { text: parent.text; color: Theme.accentFg }
                    onClicked: chatPageRoot.sendAll()
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
    // We save the current scroll position (contentY) before the reload
    // and restore it afterwards, so a user who has scrolled up to read
    // history is NOT yanked back to the bottom. If the user is already
    // at the bottom (atYBeginning), we explicitly re-pin to the bottom
    // so the newly arrived message is visible.
    Connections {
        target: MatrixClient
        function onSyncDone(payload) {
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
}
