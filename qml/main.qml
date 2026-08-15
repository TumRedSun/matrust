// main.qml — root window: Discord-style 4-column layout with overlay modals.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import MatrixClient

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 800
    minimumWidth: 720
    minimumHeight: 480
    title: MatrixClient.userId.length > 0
           ? qsTr("Matrix — %1").arg(MatrixClient.userId)
           : qsTr("Matrix Client")
    color: Theme.windowBg

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeMd

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: loginPage
    }

    Component { id: loginPage; LoginPage {} }

    // ────────────────────── MainView (Discord-style 4-column) ──────────────────────
    Component {
        id: mainView

        Rectangle {
            id: mainViewRoot
            color: Theme.windowBg
            property string activeSpaceId: ""
            property string activeRoomId: ""
            property string activeSpaceName: ""
            // "home" = DMs, "space" = rooms of selected space
            property string sidebarMode: "home"

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ── Column 1: Space icons (narrow, like Discord server icons) ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 72
                    color: Theme.sidebarBg

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Home / DMs button
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: mainViewRoot.sidebarMode === "home" ? Theme.radiusSm : 0
                                color: mainViewRoot.sidebarMode === "home" ? Theme.accent : "transparent"
                                opacity: mainViewRoot.sidebarMode === "home" ? 0.2 : 0
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "\u2302"  // ⌂ house
                                font.pixelSize: Theme.fontSizeXl
                                color: mainViewRoot.sidebarMode === "home" ? Theme.accentFg : Theme.sidebarFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainViewRoot.sidebarMode = "home"
                                    mainViewRoot.activeSpaceId = ""
                                    mainViewRoot.activeSpaceName = ""
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.border
                        }

                        // Space icon list
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: spaceIconList
                                model: SpaceModel
                                spacing: 4

                                delegate: Item {
                                    width: ListView.view.width
                                    height: 48
                                    visible: model.kind === "space"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: Theme.radiusSm
                                        color: mainViewRoot.activeSpaceId === model.id
                                               ? Theme.accent : Theme.windowBg
                                        opacity: mainViewRoot.activeSpaceId === model.id ? 0.25 : 1.0

                                        // Unread indicator dot
                                        Rectangle {
                                            visible: model.unread > 0 && mainViewRoot.activeSpaceId !== model.id
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 2
                                            width: 8; height: 8
                                            radius: 4
                                            color: model.highlight > 0 ? Theme.danger : Theme.accent
                                        }
                                    }

                                    Label {
                                        anchors.centerIn: parent
                                        text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "?"
                                        color: mainViewRoot.activeSpaceId === model.id ? Theme.accentFg : Theme.sidebarFg
                                        font.pixelSize: Theme.fontSizeLg
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            mainViewRoot.activeSpaceId = model.id
                                            mainViewRoot.activeSpaceName = model.name
                                            mainViewRoot.sidebarMode = "space"
                                            MatrixClient.loadRoomMembers(model.id)
                                        }
                                    }
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.border
                        }

                        // Settings button at bottom
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: Theme.radiusSm
                                color: settingsOverlay.visible ? Theme.accent : "transparent"
                                opacity: settingsOverlay.visible ? 0.2 : 0
                            }
                            Label {
                                anchors.centerIn: parent
                                text: "\u2699"  // ⚙ gear
                                font.pixelSize: Theme.fontSizeXl
                                color: settingsOverlay.visible ? Theme.accentFg : Theme.sidebarFg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsOverlay.visible = !settingsOverlay.visible
                            }
                        }
                    }
                }

                // ── Column 2: Room list (DMs or space rooms) ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 240
                    color: Qt.darker(Theme.sidebarBg, 1.05)

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Header: back arrow + title
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.paddingSm
                                anchors.rightMargin: Theme.paddingSm
                                spacing: Theme.spacingSm

                                ToolButton {
                                    text: "\u25C0"  // ◀
                                    font.pixelSize: Theme.fontSizeMd
                                    visible: mainViewRoot.sidebarMode === "space"
                                    onClicked: {
                                        mainViewRoot.sidebarMode = "home"
                                        mainViewRoot.activeSpaceId = ""
                                        mainViewRoot.activeSpaceName = ""
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: mainViewRoot.sidebarMode === "home"
                                          ? qsTr("Direct Messages")
                                          : qsTr("Rooms")
                                    color: Theme.sidebarFg
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                ToolButton {
                                    text: "\u27F3"  // ⟳
                                    font.pixelSize: Theme.fontSizeMd
                                    onClicked: MatrixClient.refreshRooms()
                                }

                                // "+" button — opens the user search dialog.
                                // In DM mode it lets you start a new DM;
                                // we keep it in both modes so users can start
                                // a DM from anywhere.
                                ToolButton {
                                    text: "\u2795"  // ➕
                                    font.pixelSize: Theme.fontSizeMd
                                    onClicked: {
                                        userSearchDialog.open()
                                    }
                                }
                            }
                        }

                        // Search/filter field
                        TextField {
                            id: roomSearch
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.paddingSm
                            Layout.rightMargin: Theme.paddingSm
                            Layout.bottomMargin: Theme.spacingSm
                            placeholderText: qsTr("Search\u2026")
                            color: Theme.sidebarFg
                            font.pixelSize: Theme.fontSizeSm
                            background: Rectangle {
                                color: Theme.sidebarBg
                                radius: Theme.radiusSm
                                border.color: Theme.border
                                border.width: 1
                            }
                        }

                        // Room list (filters based on sidebarMode)
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                id: roomList
                                model: RoomModel
                                spacing: 0

                                delegate: Item {
                                    width: ListView.view.width
                                    // Filter rules:
                                    //   - In "home" (DM) mode:
                                    //       show direct rooms that have ≥1 message
                                    //       OR the room the user has explicitly
                                    //       navigated to (so a freshly-created
                                    //       DM is reachable even before its
                                    //       first message arrives).
                                    //   - In "space" mode: show non-direct
                                    //       rooms.
                                    property bool showItem: mainViewRoot.sidebarMode === "home"
                                            ? (model.is_direct && (model.message_count > 0
                                                || model.room_id === mainViewRoot.activeRoomId))
                                            : !model.is_direct
                                    height: showItem ? 52 : 0
                                    visible: showItem

                                    Rectangle {
                                        anchors.fill: parent
                                        color: mainViewRoot.activeRoomId === model.room_id ? Theme.accent : "transparent"
                                        opacity: mainViewRoot.activeRoomId === model.room_id ? 0.18 : 0
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.paddingSm
                                        anchors.rightMargin: Theme.paddingSm
                                        spacing: Theme.spacingSm

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: model.is_direct
                                                    ? 16  // circle for DMs
                                                    : Theme.radiusSm  // rounded for rooms
                                            color: model.is_direct ? Theme.success : Theme.accent
                                            opacity: 0.3
                                            Label {
                                                anchors.centerIn: parent
                                                text: model.name.length > 0 ? model.name.charAt(0).toUpperCase() : "#"
                                                color: Theme.accentFg
                                                font.pixelSize: Theme.fontSizeSm
                                                font.bold: true
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Label {
                                                Layout.fillWidth: true
                                                text: model.name.length > 0 ? model.name : model.room_id
                                                color: Theme.sidebarFg
                                                elide: Text.ElideRight
                                                font.pixelSize: Theme.fontSizeSm
                                                font.bold: model.has_unread
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: model.last_event
                                                color: Theme.muted
                                                elide: Text.ElideRight
                                                font.pixelSize: Theme.fontSizeXs
                                            }
                                        }

                                        // Unread badge
                                        Rectangle {
                                            visible: model.unread_count > 0
                                            Layout.preferredWidth: Math.max(20, unreadLbl.implicitWidth + 8)
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: model.highlight_count > 0 ? Theme.danger : Theme.accent
                                            Label {
                                                id: unreadLbl
                                                anchors.centerIn: parent
                                                text: model.unread_count
                                                color: Theme.accentFg
                                                font.pixelSize: Theme.fontSizeXs
                                                font.bold: true
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            mainViewRoot.activeRoomId = model.room_id
                                            MatrixClient.loadRoomMessages(model.room_id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Column 3: Chat area ──
                ChatPage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    roomId: mainViewRoot.activeRoomId
                }

                // ── Column 4: Member list (right sidebar) ──
                MemberListPanel {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 220
                    visible: mainViewRoot.sidebarMode === "space" && mainViewRoot.activeSpaceId.length > 0
                    spaceId: mainViewRoot.activeSpaceId
                    spaceName: mainViewRoot.activeSpaceName
                }
            }

            // When a room is selected, close settings overlay
            onActiveRoomIdChanged: {
                if (activeRoomId.length > 0) {
                    settingsOverlay.visible = false
                }
            }
        }
    }

    // ────────────────────── Settings Overlay (modal with dimmed background) ──────────────────────
    Rectangle {
        id: settingsOverlay
        visible: false
        anchors.fill: parent
        color: "transparent"
        z: 100  // above everything

        // Dim background
        MouseArea {
            anchors.fill: parent
            onClicked: settingsOverlay.visible = false
        }
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.6
        }

        // Settings panel (centered, like Discord).
        // Sized to nearly fill the window so users with big screens / lots
        // of theme settings don't have to scroll the panel itself — only
        // the inner ScrollView scrolls.
        Rectangle {
            id: settingsPanel
            width: parent.width - 40
            height: parent.height - 40
            anchors.centerIn: parent
            color: Theme.windowBg
            radius: Theme.radiusLg
            border.color: Theme.border
            border.width: 1

            // Prevent clicks from closing when inside the panel
            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            SettingsOverlay {
                anchors.fill: parent
                anchors.margins: 1  // keep the rounded border visible
                onCloseSettings: settingsOverlay.visible = false
            }
        }

        // Prevent interaction with underlying UI while overlay is open
        MouseArea {
            anchors.fill: parent
            visible: settingsOverlay.visible
            onClicked: {}  // swallow all clicks
            z: -1
        }
    }

    // ────────────────────── User Search Dialog ──────────────────────
    // Centered modal for finding users to start DMs with.
    // User flow:
    //   1. Type a (partial) username in the search field.
    //   2. MatrixClient.searchUsers() emits usersSearchDone(json).
    //   3. The JSON is parsed into a ListModel and rendered below.
    //   4. Each row has a "message" icon on the right — clicking it calls
    //      MatrixClient.openDirectMessage(userId), which emits dmOpened(rid).
    //   5. dmOpened sets activeRoomId and closes the dialog. Until the first
    //      real message is sent, the room stays unpinned in the DM sidebar
    //      (see RoomModel filter in the roomList delegate).
    Dialog {
        id: userSearchDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 80)
        height: Math.min(520, parent.height - 80)
        background: Rectangle {
            color: Theme.windowBg
            radius: Theme.radiusLg
            border.color: Theme.border
            border.width: 1
        }

        // Hold the parsed search results.
        ListModel { id: userSearchResults }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.paddingMd
            spacing: Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm
                Label {
                    text: qsTr("Find user")
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.windowFg
                }
                Item { Layout.fillWidth: true }
                ToolButton {
                    text: "\u2715"  // ✕
                    font.pixelSize: Theme.fontSizeMd
                    onClicked: userSearchDialog.close()
                }
            }

            // Search input — queries fire after every keystroke (debounced
            // via a small Timer so we don't spam the server).
            TextField {
                id: userSearchField
                Layout.fillWidth: true
                placeholderText: qsTr("Type a username (e.g. @alice:matrix.org)…")
                color: Theme.windowFg
                font.pixelSize: Theme.fontSizeSm
                onTextChanged: userSearchTimer.restart()
                background: Rectangle {
                    color: Theme.sidebarBg
                    radius: Theme.radiusSm
                    border.color: Theme.border
                    border.width: 1
                }
            }

            // Results list.
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: userSearchList
                    model: userSearchResults
                    spacing: 2

                    delegate: Item {
                        width: ListView.view.width
                        height: 56

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Theme.radiusSm
                            color: userSearchList.currentIndex === index ? Theme.accent : "transparent"
                            opacity: userSearchList.currentIndex === index ? 0.15 : 0
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.paddingSm
                            anchors.rightMargin: Theme.paddingSm
                            spacing: Theme.spacingSm

                            // Avatar (uses mxc:// via avatar_cache if available,
                            // otherwise shows the first letter of the display name).
                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 18
                                color: Theme.accent
                                opacity: 0.3
                                Label {
                                    anchors.centerIn: parent
                                    text: {
                                        var dn = model.display_name || model.user_id
                                        return dn.length > 0 ? dn.charAt(0).toUpperCase() : "?"
                                    }
                                    color: Theme.accentFg
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    Layout.fillWidth: true
                                    text: model.display_name.length > 0 ? model.display_name : qsTr("(no display name)")
                                    color: Theme.windowFg
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: model.user_id
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeXs
                                    elide: Text.ElideRight
                                }
                            }

                            // Message icon — click to open the DM.
                            ToolButton {
                                text: "\u2709"  // ✉
                                font.pixelSize: Theme.fontSizeLg
                                Layout.preferredWidth: 40
                                onClicked: {
                                    MatrixClient.openDirectMessage(model.user_id)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            // Click on the row (not the buttons) selects it.
                            onClicked: userSearchList.currentIndex = index
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: userSearchResults.count === 0 && userSearchField.text.length > 0
                text: qsTr("No users found. Try the full Matrix ID (e.g. @alice:matrix.org).")
                color: Theme.muted
                font.pixelSize: Theme.fontSizeXs
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Timer {
            id: userSearchTimer
            interval: 300
            onTriggered: {
                var q = userSearchField.text.trim()
                if (q.length === 0) {
                    userSearchResults.clear()
                    return
                }
                MatrixClient.searchUsers(q)
            }
        }

        onOpened: {
            userSearchField.text = ""
            userSearchResults.clear()
            userSearchField.forceActiveFocus()
        }
    }

    // ────────────────────── Confirm Leave Room Dialog ──────────────────────
    Dialog {
        id: leaveRoomDialog
        modal: true
        anchors.centerIn: parent
        width: Math.min(420, parent.width - 80)
        background: Rectangle {
            color: Theme.windowBg
            radius: Theme.radiusMd
            border.color: Theme.border
            border.width: 1
        }
        property string roomId: ""
        property string roomName: ""
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.paddingMd
            spacing: Theme.spacingSm
            Label {
                text: qsTr("Close conversation?")
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.windowFg
            }
            Label {
                Layout.fillWidth: true
                text: leaveRoomDialog.roomName.length > 0
                      ? qsTr("This will leave \"%1\". Your and the other participant's messages will no longer be visible to you in this client (the history remains on the server).").arg(leaveRoomDialog.roomName)
                      : qsTr("This will leave the room. Your and the other participant's messages will no longer be visible to you in this client.")
                color: Theme.windowFg
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSm
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Cancel")
                    onClicked: leaveRoomDialog.close()
                }
                Button {
                    text: qsTr("Close")
                    background: Rectangle { color: Theme.danger; radius: Theme.radiusSm }
                    contentItem: Label { text: parent.text; color: Theme.accentFg }
                    onClicked: {
                        if (leaveRoomDialog.roomId.length > 0) {
                            MatrixClient.leaveRoom(leaveRoomDialog.roomId)
                        }
                        leaveRoomDialog.close()
                    }
                }
            }
        }
    }

    // ── Toast ──
    Rectangle {
        id: toast
        property string text
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        color: text.length > 0 ? Theme.accent : "transparent"
        radius: Theme.radiusMd
        visible: text.length > 0
        opacity: 0.95
        width: toastLabel.implicitWidth + 32
        height: toastLabel.implicitHeight + 16
        Label {
            id: toastLabel
            anchors.centerIn: parent
            text: toast.text
            color: Theme.accentFg
            font.pixelSize: Theme.fontSizeSm
        }
        Timer { id: toastTimer; interval: 3000; onTriggered: toast.text = "" }
    }

    Connections {
        target: MatrixClient
        function onLastErrorChanged() {
            var err = MatrixClient.lastError;
            if (err && err.length > 0) {
                toast.text = err;
                toastTimer.start();
            }
        }
        function onLoggedIn(userId) {
            stack.replace(null, mainView);
        }
        function onLoggedOut() {
            stack.replace(null, loginPage);
            settingsOverlay.visible = false;
        }
        function onFileDownloaded(roomId, mxc, localPath) {
            root.showToast(qsTr("Downloaded to %1").arg(localPath));
        }
        // Search results arrived — parse JSON into userSearchResults.
        function onUsersSearchDone(resultsJson) {
            userSearchResults.clear()
            try {
                var arr = JSON.parse(resultsJson)
                for (var i = 0; i < arr.length; i++) {
                    userSearchResults.append(arr[i])
                }
            } catch (e) {
                console.warn("users_search_done: bad JSON", e)
            }
        }
        // DM opened — switch to the room and close the search dialog.
        function onDmOpened(roomId) {
            if (roomId.length === 0) return
            mainViewRoot.sidebarMode = "home"
            mainViewRoot.activeRoomId = roomId
            MatrixClient.loadRoomMessages(roomId)
            userSearchDialog.close()
        }
        // Room left — clear active room if it was the one we left.
        function onRoomLeft(roomId) {
            if (mainViewRoot.activeRoomId === roomId) {
                mainViewRoot.activeRoomId = ""
            }
            root.showToast(qsTr("Conversation closed"))
        }
    }

    Component.onCompleted: {
        // Force a fresh re-read of every Theme-driven property so changes
        // the user made via the Settings dialog (in a previous session)
        // propagate even if QML cached a stale value during the initial
        // singleton construction race.
        Theme.applyPreset(Theme.preset)
        MatrixClient.autoLogin()
    }

    // Re-apply the theme when any of its NOTIFY signals fire. QML bindings
    // *should* update automatically, but qmetaobject's getter-based
    // properties occasionally need a nudge — this forces every property
    // to be re-read from the ThemeState RefCell.
    Connections {
        target: Theme
        function onThemeChanged() {
            // No-op: the bindings re-evaluate automatically. This handler
            // exists only so the Connections object compiles.
        }
    }

    function showToast(text) {
        toast.text = text;
        toastTimer.start();
    }
}
