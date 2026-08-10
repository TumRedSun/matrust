// ChatPage.qml — main chat view: header, message list, composer.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import MatrixClient

Rectangle {
    color: Theme.window_bg
    property string roomId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.sidebar_bg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padding_md
                anchors.rightMargin: Theme.padding_md
                spacing: Theme.spacing_sm

                Label {
                    text: roomId.length > 0 ? qsTr("Room %1").arg(roomId) : qsTr("No room selected")
                    color: Theme.sidebar_fg
                    font.pixelSize: Theme.font_size_md
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: MatrixClient.busy ? qsTr("Syncing…") : qsTr("Ready")
                    color: Theme.muted
                    font.pixelSize: Theme.font_size_sm
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
                model: MatrixClient.messageModel()
                spacing: Theme.spacing_xs
                verticalLayoutDirection: ListView.BottomToTop

                delegate: MessageBubble {
                    width: messagesView.width - Theme.padding_md * 2
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
            color: Theme.sidebar_bg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padding_sm
                anchors.rightMargin: Theme.padding_sm
                spacing: Theme.spacing_sm

                Button {
                    text: qsTr("📎")
                    background: Rectangle { color: "transparent"; radius: Theme.radius_sm }
                    font.pixelSize: Theme.font_size_lg
                    onClicked: fileDialog.open()
                    enabled: roomId.length > 0
                }
                Button {
                    text: qsTr("🖼")
                    background: Rectangle { color: "transparent"; radius: Theme.radius_sm }
                    font.pixelSize: Theme.font_size_lg
                    onClicked: imageDialog.open()
                    enabled: roomId.length > 0
                }
                Button {
                    text: qsTr("🎬")
                    background: Rectangle { color: "transparent"; radius: Theme.radius_sm }
                    font.pixelSize: Theme.font_size_lg
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
                        color: Theme.sidebar_fg
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
                    background: Rectangle { color: parent.enabled ? Theme.accent : Theme.muted; radius: Theme.radius_sm }
                    contentItem: Label { text: parent.text; color: Theme.accent_fg }
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
        target: MatrixClient.messageModel()
        function onHistoryLoaded(rid) {
            if (rid === roomId) {
                messagesView.positionViewAtBeginning()
            }
        }
    }
}
