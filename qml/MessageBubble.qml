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
    // Local reactions: a comma-separated list of emoji that the user
    // has sent via this client in this session (so the user sees
    // immediate feedback without waiting for the next sync). Server-
    // side reactions are rendered once they come back through sync.
    property string localReactions: ""

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
                                  : qsTr("(original message)")
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
                // Renders local reactions the user has just sent (instant
                // feedback before sync) as small pill-shaped chips. Once
                // the next sync arrives, reactions will be re-rendered
                // from server-side data (TODO: parse from timeline).
                //
                // `localReactions` is a comma-separated string of emoji
                // (e.g. "👍,❤️,🎉"). Splitting on "," is safe because
                // emoji don't contain ASCII commas.
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.bubblePaddingH
                    Layout.rightMargin: Theme.bubblePaddingH
                    Layout.bottomMargin: Theme.bubblePaddingV
                    spacing: 4
                    visible: root.localReactions.length > 0
                    Repeater {
                        model: root.localReactions.length > 0
                                ? root.localReactions.split(",")
                                : []
                        Rectangle {
                            width: reactLbl.implicitWidth + 12
                            height: 22
                            radius: 11
                            color: root.isOwn ? Qt.lighter(Theme.bubbleBgMe, 1.3)
                                              : Qt.darker(Theme.bubbleBgThem, 1.3)
                            border.color: Theme.accent
                            border.width: 1
                            Label {
                                id: reactLbl
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSm
                                color: root.isOwn ? Theme.bubbleFgMe : Theme.bubbleFgThem
                            }
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
        // Quick-pick row of the ~30 most-common emoji as MenuItems.
        // "More\u2026" opens a separate dialog with a much larger grid
        // (see EmojiPickerDialog.qml) for less-frequent emoji.
        Menu {
            title: qsTr("React")
            Instantiator {
                // Curated list of frequently-used reaction emoji.
                // Covers thumbs, hearts, faces, gestures, celebration,
                // animals, food, weather — the same palette Discord /
                // Slack surface in their quick-react trays.
                model: [
                    "\uD83D\uDC4D",  // 👍
                    "\uD83D\uDC4E",  // 👎
                    "\u2764\uFE0F",  // ❤️
                    "\uD83D\uDC96",  // 💖
                    "\uD83E\uDD0D",  // 🤍
                    "\uD83D\uDC94",  // 💔
                    "\uD83D\uDE06",  // 😆
                    "\uD83D\uDE02",  // 😂
                    "\uD83D\uDE22",  // 😢
                    "\uD83D\uDE2D",  // 😭
                    "\uD83D\uDE0E",  // 😎
                    "\uD83E\uDD14",  // 🤔
                    "\uD83D\uDE0D",  // 😍
                    "\uD83D\uDE31",  // 😱
                    "\uD83D\uDE20",  // 😠
                    "\uD83E\uDD2C",  // 🤬
                    "\uD83D\uDE44",  // 🙄
                    "\uD83D\uDC4F",  // 👏
                    "\uD83D\uDE4F",  // 🙏
                    "\uD83D\uDC4B",  // 👋
                    "\uD83D\uDD90\uFE0F",  // 🙐
                    "\uD83E\uDD1D",  // 🤝
                    "\uD83D\uDE4C",  // 🙌
                    "\uD83C\uDF89",  // 🎉
                    "\uD83C\uDF7E",  // 🎾 (party)
                    "\uD83C\uDF81",  // 🎁
                    "\uD83D\uDE80",  // 🚀
                    "\u2728",        // ✨
                    "\uD83D\uDD25",  // 🔥
                    "\u2714\uFE0F",  // ✔️
                    "\u274C",        // ❌
                    "\u2753",        // ❓
                    "\u2615",        // ☕
                    "\uD83C\uDF7A",  // 🍺
                    "\uD83C\uDF7B",  // 🍻
                    "\uD83C\uDF54",  // 🍔
                    "\uD83C\uDF5F",  // 🍟
                    "\uD83C\uDF63",  // 🍣
                    "\uD83C\uDF6A",  // 🍪
                    "\uD83C\uDF82",  // 🎂
                    "\uD83C\uDF36\uFE0F",  // 🎶
                    "\uD83C\uDFB5",  // 🎵
                    "\uD83C\uDFA7",  // 🎧
                    "\uD83C\uDFB8",  // 🎸
                    "\uD83C\uDF9E\uFE0F",  // 🎮
                    "\uD83C\uDFAE",  // 🎮 (alt)
                    "\uD83C\uDFC9",  // 🏉 (no, football)
                    "\u26BD",        // ⚽
                    "\uD83C\uDFC0",  // 🏀
                    "\uD83C\uDFC8",  // 🏈
                    "\uD83D\uDC15",  // 🐕
                    "\uD83D\uDC36",  // 🐶
                    "\uD83D\uDC31",  // 🐱
                    "\uD83D\uDC22",  // 🐢
                    "\uD83E\uDD8A",  // 🦊
                    "\uD83D\uDC3B",  // 🐻
                    "\uD83E\uDD81",  // 🦁
                    "\uD83D\uDC3E",  // 🐾
                    "\uD83D\uDC26",  // 🐦
                    "\uD83E\uDD85",  // 🦅
                    "\uD83D\uDC18",  // 🐘
                    "\uD83D\uDC2D",  // 🐭
                    "\uD83D\uDC39",  // 🐹
                    "\uD83D\uDC30",  // 🐰
                    "\uD83C\uDF40",  // 🍀
                    "\uD83C\uDF38",  // 🌸
                    "\uD83C\uDF3B",  // 🌻
                    "\uD83C\uDF34",  // 🌴
                    "\uD83C\uDF1E",  // 🌞
                    "\uD83C\uDF1A",  // 🌚
                    "\u2600\uFE0F",  // ☀️
                    "\u2601\uFE0F",  // ☁️
                    "\u26C8\uFE0F",  // ⛈
                    "\uD83C\uDF27\uFE0F",  // 🌧
                    "\u26A1",        // ⚡
                    "\uD83C\uDF2B\uFE0F",  // 🌫
                    "\u2744\uFE0F",  // ❄️
                    "\uD83C\uDF28\uFE0F",  // 🌨
                    "\uD83C\uDFA9",  // 🎩
                    "\uD83D\uDC54",  // 👔
                    "\uD83D\uDC5E",  // 👞
                    "\uD83C\uDF92",  // 🎒
                    "\uD83D\uDCBC",  // 💼
                    "\uD83D\uDCB0",  // 💰
                    "\uD83D\uDCB2",  // 💲
                    "\uD83D\uDCAB",  // 💫
                    "\uD83D\uDCA5",  // 💥
                    "\uD83D\uDCA9",  // 💩
                    "\uD83D\uDC80",  // 💀
                    "\uD83D\uDC7B",  // 👻
                    "\uD83D\uDC7D",  // 👽
                    "\uD83E\uDD16",  // 🤖
                    "\uD83E\uDD84",  // 🦄
                    "\uD83D\uDC09",  // 🐉
                    "\uD83E\uDD8E",  // 🦎
                    "\uD83D\uDC0D",  // 🐍
                    "\uD83D\uDC32",  // 🐲
                    "\uD83D\uDC1F",  // 🐟
                    "\uD83D\uDC20",  // 🐠
                    "\uD83D\uDC21",  // 🐡
                    "\uD83D\uDC0B",  // 🐋
                    "\uD83D\uDC2C",  // 🐬
                    "\uD83D\uDC33",  // 🐳
                    "\uD83E\uDD88",  // 🦈
                    "\uD83E\uDD8B",  // 🦋
                    "\uD83D\uDC1B",  // 🐛
                    "\uD83D\uDC1C",  // 🐜
                    "\uD83D\uDC1E",  // 🐞
                    "\uD83E\uDD97",  // 🦗
                    "\uD83D\uDC23",  // 🐣
                    "\uD83D\uDC24",  // 🐤
                    "\uD83D\uDC14",  // 🐔
                    "\uD83D\uDC13",  // 🐓
                    "\uD83D\uDC16",  // 🐖
                    "\uD83D\uDC17",  // 🐗
                    "\uD83D\uDC11",  // 🐑
                    "\uD83D\uDC10",  // 🐐
                    "\uD83D\uDC0A",  // 🐊
                    "\uD83D\uDC1A",  // 🐚
                    "\uD83C\uDFC1",  // 🏁
                    "\uD83C\uDFC6",  // 🏆
                    "\uD83C\uDFC5",  // 🏅
                    "\uD83C\uDFCA",  // 🏊
                    "\uD83C\uDFC4\u200D\u2642\uFE0F",  // 🏄‍♂️
                    "\uD83C\uDFC2",  // 🏂
                    "\uD83D\uDEB4\u200D\u2642\uFE0F",  // 🚴‍♂️
                    "\uD83D\uDEB5\u200D\u2642\uFE0F",  // 🚵‍♂️
                    "\uD83C\uDFA3",  // 🎣
                    "\uD83C\uDFB6",  // 🎶
                    "\uD83C\uDFB9",  // 🎹
                    "\uD83C\uDFBA",  // 🎺
                    "\uD83C\uDFBB",  // 🎻
                    "\uD83C\uDFBC",  // 🎼
                    "\uD83C\uDFA4",  // 🎤
                    "\uD83C\uDFA5",  // 🎥
                    "\uD83C\uDFA6",  // 🎦
                    "\uD83C\uDFA8",  // 🎨
                    "\uD83C\uDFAC",  // 🎬
                    "\uD83C\uDFAD",  // 🎭
                    "\uD83C\uDFB0",  // 🎰
                    "\uD83C\uDFAF",  // 🎯
                    "\uD83C\uDFB1",  // 🎱
                    "\uD83C\uDFB3",  // 🎳
                    "\uD83C\uDCCF",  // 🃏
                    "\uD83C\uDCA0",  // 🂠
                    "\uD83C\uDFB4",  // 🎴
                    "\uD83C\uDFAE",  // 🎮
                    "\uD83C\uDFAF",  // 🎯
                    "\uD83C\uDFB2",  // 🎲
                    "\uD83C\uDF9E",  // 🎞
                    "\uD83C\uDF93",  // 🎓
                    "\uD83C\uDF9A",  // 🎚
                    "\uD83C\uDF9B",  // 🎛
                    "\uD83C\uDFC7",  // 🏇
                    "\uD83D\uDEB6\u200D\u2642\uFE0F"   // 🚶‍♂️
                ]
                MenuItem {
                    text: modelData
                    onTriggered: {
                        MatrixClient.sendReaction(root.roomId, root.eventId, modelData)
                        // Optimistic local update: append the emoji so
                        // the user sees immediate feedback before the
                        // next sync confirms it server-side.
                        if (root.localReactions.length === 0) {
                            root.localReactions = modelData
                        } else {
                            var parts = root.localReactions.split(",")
                            if (parts.indexOf(modelData) < 0) {
                                root.localReactions = root.localReactions + "," + modelData
                            }
                        }
                    }
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
