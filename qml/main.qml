// main.qml — root window: Discord-style 3-column layout.
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

    // ────────────────────── MainView (Discord-style) ──────────────────────
    Component {
        id: mainView

        Rectangle {
            id: mainViewRoot
            color: Theme.windowBg
            property string activeSpaceId: ""
            property string activeRoomId: ""
            property bool showSpaceList: true   // true = space icons, false = rooms for active space

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

                        // Logo / Home button
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            Rectangle {
                                anchors.fill: parent
                                radius: mainViewRoot.showSpaceList ? Theme.radiusSm : 0
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: mainViewRoot.showSpaceList ? 1 : 0
                                anchors.margins: 4
                            }
                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/assets/logo.svg"
                                sourceSize: Qt.size(32, 32)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mainViewRoot.showSpaceList = true
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
                                            mainViewRoot.showSpaceList = false
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

                        // Bottom nav: Profile, Settings, Appearance, Logout
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                Label { Layout.alignment: Qt.AlignHCenter; text: "👤"; font.pixelSize: Theme.fontSizeLg }
                                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Me"); font.pixelSize: Theme.fontSizeXs; color: Theme.sidebarFg }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsStack.currentIndex = 0  // Profile
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                Label { Layout.alignment: Qt.AlignHCenter; text: "⚙"; font.pixelSize: Theme.fontSizeLg }
                                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Set"); font.pixelSize: Theme.fontSizeXs; color: Theme.sidebarFg }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsStack.currentIndex = 1  // Settings
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                Label { Layout.alignment: Qt.AlignHCenter; text: "🎨"; font.pixelSize: Theme.fontSizeLg }
                                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Look"); font.pixelSize: Theme.fontSizeXs; color: Theme.sidebarFg }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsStack.currentIndex = 2  // Appearance
                            }
                        }

                        // Logout
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 0
                                Label { Layout.alignment: Qt.AlignHCenter; text: "🚪"; font.pixelSize: Theme.fontSizeLg }
                                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Out"); font.pixelSize: Theme.fontSizeXs; color: Theme.sidebarFg }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MatrixClient.logout()
                            }
                        }
                    }
                }

                // ── Column 2: Room list / Settings pages ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 240
                    color: Qt.darker(Theme.sidebarBg, 1.05)

                    StackLayout {
                        id: settingsStack
                        anchors.fill: parent
                        currentIndex: -1  // -1 = show room list

                        // Page 0: Profile
                        ProfilePage {}

                        // Page 1: Settings
                        SettingsPage {}

                        // Page 2: Appearance
                        AppearancePage {}
                    }

                    // Room list (shown when settingsStack.currentIndex === -1)
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        visible: settingsStack.currentIndex === -1

                        // Back arrow to return to space list + space name
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
                                    text: "◀"
                                    font.pixelSize: Theme.fontSizeMd
                                    visible: !mainViewRoot.showSpaceList
                                    onClicked: mainViewRoot.showSpaceList = true
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: mainViewRoot.activeSpaceId.length > 0
                                          ? qsTr("Rooms") : qsTr("All rooms")
                                    color: Theme.sidebarFg
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                ToolButton {
                                    text: "⟳"
                                    font.pixelSize: Theme.fontSizeMd
                                    onClicked: MatrixClient.refreshRooms()
                                }
                            }
                        }

                        // Search/filter field (placeholder)
                        TextField {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.paddingSm
                            Layout.rightMargin: Theme.paddingSm
                            Layout.bottomMargin: Theme.spacingSm
                            placeholderText: qsTr("Search rooms…")
                            color: Theme.sidebarFg
                            font.pixelSize: Theme.fontSizeSm
                            background: Rectangle {
                                color: Theme.sidebarBg
                                radius: Theme.radiusSm
                                border.color: Theme.border
                                border.width: 1
                            }
                        }

                        // Room list
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
                                    height: 52

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
            }

            // When settings stack is shown, hide chat
            onActiveRoomIdChanged: {
                if (activeRoomId.length > 0) {
                    settingsStack.currentIndex = -1
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
        }
        function onFileDownloaded(roomId, mxc, localPath) {
            root.showToast(qsTr("Downloaded to %1").arg(localPath));
        }
    }

    Component.onCompleted: MatrixClient.autoLogin()

    function showToast(text) {
        toast.text = text;
        toastTimer.start();
    }
}
