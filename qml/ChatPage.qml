// ChatPage.qml — main chat view: header, message list, composer.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    color: Theme.windowBg
    property string roomId: ""

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

                Label {
                    text: roomId.length > 0 ? qsTr("Room %1").arg(roomId) : qsTr("No room selected")
                    color: Theme.sidebarFg
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: MatrixClient.busy ? qsTr("Syncing…") : qsTr("Ready")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSm
                }
                // Close conversation button — visible only when a room is open.
                // Triggers the "close conversation" dialog (leave room).
                ToolButton {
                    text: "\u2715"  // ✕
                    font.pixelSize: Theme.fontSizeMd
                    visible: roomId.length > 0
                    enabled: roomId.length > 0
                    onClicked: {
                        // Look up the room's display name from RoomModel so
                        // the confirm dialog can show it. We don't gate the
                        // button on is_direct — users may want to leave a
                        // regular room too.
                        var name = ""
                        for (var j = 0; j < RoomModel.count; j++) {
                            var ix = RoomModel.index(j, 0)
                            var rid = RoomModel.data(ix, 257).toString()
                            if (rid === roomId) {
                                name = RoomModel.data(ix, 257 + 1).toString()
                                break
                            }
                        }
                        leaveRoomDialog.roomId = roomId
                        leaveRoomDialog.roomName = name
                        leaveRoomDialog.open()
                    }
                }
            }
        }

        // ── Messages ──
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: messagesView
                model: MessageModel
                spacing: Theme.spacingXs
                verticalLayoutDirection: ListView.BottomToTop

                delegate: MessageBubble {
                    width: messagesView.width - Theme.paddingMd * 2
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    eventId: model.event_id
                    sender: model.sender_display.length > 0 ? model.sender_display : model.sender
                    avatarUrl: model.avatar_url
                    body: model.body
                    bodyHtml: model.body_html
                    ts: model.ts
                    isOwn: model.is_own
                    kind: model.kind
                    mxcUrl: model.mxc_url
                    fileName: model.file_name
                    fileSize: model.file_size
                    mimeType: model.mime_type
                    roomId: parent.parent.parent.roomId
                }
            }
        }

        // ── Composer ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: Theme.sidebarBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.paddingSm
                anchors.rightMargin: Theme.paddingSm
                spacing: Theme.spacingSm

                Button {
                    text: qsTr("📎")
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: fileDialog.open()
                    enabled: roomId.length > 0
                }
                Button {
                    text: qsTr("🖼")
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: imageDialog.open()
                    enabled: roomId.length > 0
                }
                Button {
                    text: qsTr("🎬")
                    background: Rectangle { color: "transparent"; radius: Theme.radiusSm }
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: videoDialog.open()
                    enabled: roomId.length > 0
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: composer
                        placeholderText: qsTr("Type a message…")
                        placeholderTextColor: Theme.muted
                        color: Theme.sidebarFg
                        wrapMode: TextArea.Wrap
                        background: Rectangle { color: "transparent" }
                        Keys.onReturnPressed: function(event) {
                            if (event.modifiers & Qt.ControlModifier) {
                                composer.append("\n")
                            } else {
                                event.accepted = true
                                if (composer.text.trim().length > 0 && roomId.length > 0) {
                                    MatrixClient.sendText(roomId, composer.text)
                                    composer.text = ""
                                }
                            }
                        }
                    }
                }

                Button {
                    text: qsTr("Send")
                    enabled: roomId.length > 0 && composer.text.trim().length > 0
                    background: Rectangle { color: parent.enabled ? Theme.accent : Theme.muted; radius: Theme.radiusSm }
                    contentItem: Label { text: parent.text; color: Theme.accentFg }
                    onClicked: {
                        MatrixClient.sendText(roomId, composer.text)
                        composer.text = ""
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Choose a file to send")
        onAccepted: {
            var path = fileDialog.currentFile.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            MatrixClient.sendFile(roomId, path, "", "file")
        }
    }
    FileDialog {
        id: imageDialog
        title: qsTr("Choose an image")
        nameFilters: ["Images (*.png *.jpg *.jpeg *.gif *.webp *.svg)"]
        onAccepted: {
            var path = imageDialog.currentFile.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            MatrixClient.sendFile(roomId, path, "image/*", "image")
        }
    }
    FileDialog {
        id: videoDialog
        title: qsTr("Choose a video")
        nameFilters: ["Videos (*.mp4 *.webm *.mkv *.mov)"]
        onAccepted: {
            var path = videoDialog.currentFile.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            MatrixClient.sendFile(roomId, path, "video/*", "video")
        }
    }

    Connections {
        target: MessageModel
        function onHistoryLoaded(rid) {
            if (rid === roomId) {
                messagesView.positionViewAtBeginning()
            }
        }
    }
}
