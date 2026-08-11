// main.qml — root window with embedded MainView.
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
    title: MatrixClient.user_id.length > 0
           ? qsTr("Matrix — %1").arg(MatrixClient.user_id)
           : qsTr("Matrix Client")
    color: Theme.window_bg

    font.family: Theme.font_family
    font.pixelSize: Theme.font_size_md

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: loginPage
    }

    Component { id: loginPage; LoginPage {} }

    // ─────────────────────────── MainView ───────────────────────────
    Component {
        id: mainView

        Rectangle {
            id: mainViewRoot
            color: Theme.window_bg
            property int currentPage: 0
            property string activeRoomId: ""

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ── Navigation rail ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 72
                    color: Theme.sidebar_bg

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            Image {
                                anchors.centerIn: parent
                                source: "qrc:/assets/logo.svg"
                                sourceSize: Qt.size(36, 36)
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Repeater {
                            model: [
                                { icon: "🗄", label: qsTr("Spaces"), page: 0 },
                                { icon: "💬", label: qsTr("Rooms"), page: 1 },
                                { icon: "👤", label: qsTr("Profile"), page: 2 },
                                { icon: "⚙", label: qsTr("Settings"), page: 3 },
                                { icon: "🎨", label: qsTr("Look"), page: 4 }
                            ]
                            delegate: Item {
                                Layout.fillWidth: true
                                height: 56

                                property bool active: mainViewRoot.currentPage === modelData.page

                                Rectangle {
                                    anchors.fill: parent
                                    color: parent.active ? Theme.accent : "transparent"
                                    opacity: parent.active ? 0.18 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.animationDurationMs } }
                                }
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: Theme.accent
                                    visible: parent.active
                                }
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                        font.pixelSize: Theme.font_size_lg
                                    }
                                    Label {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: Theme.font_size_xs
                                        color: parent.parent.active ? Theme.accent : Theme.sidebar_fg
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        mainViewRoot.currentPage = modelData.page
                                        if (modelData.page === 2) {
                                            MatrixClient.profile_manager().refresh()
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Logout button
                        Item {
                            Layout.fillWidth: true
                            height: 56
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Label { Layout.alignment: Qt.AlignHCenter; text: "🚪"; font.pixelSize: Theme.font_size_lg }
                                Label { Layout.alignment: Qt.AlignHCenter; text: qsTr("Logout"); font.pixelSize: Theme.font_size_xs; color: Theme.sidebar_fg }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MatrixClient.logout()
                            }
                        }
                    }
                }

                // ── Content stack ──
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: mainViewRoot.currentPage

                    SpacesPage {
                        onRoomSelected: function(roomId) {
                            mainViewRoot.activeRoomId = roomId
                            MatrixClient.load_room_messages(roomId)
                            mainViewRoot.currentPage = 1
                        }
                    }
                    ChatPage { roomId: mainViewRoot.activeRoomId }
                    ProfilePage {}
                    SettingsPage {}
                    AppearancePage {}
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
        radius: Theme.radius_md
        visible: text.length > 0
        opacity: 0.95
        width: toastLabel.implicitWidth + 32
        height: toastLabel.implicitHeight + 16
        Label {
            id: toastLabel
            anchors.centerIn: parent
            text: toast.text
            color: Theme.accent_fg
            font.pixelSize: Theme.font_size_sm
        }
        Timer { id: toastTimer; interval: 3000; onTriggered: toast.text = "" }
    }

    Connections {
        target: MatrixClient
        function onLast_error_changed() {
            if (MatrixClient.last_error.length > 0) {
                toast.text = MatrixClient.last_error;
                toastTimer.start();
            }
        }
        function onLogged_in(userId) {
            stack.replace(null, mainView);
        }
        function onLogged_out() {
            stack.replace(null, loginPage);
        }
        function onFile_downloaded(roomId, mxc, localPath) {
            root.showToast(qsTr("Downloaded to %1").arg(localPath));
        }
    }

    Component.onCompleted: MatrixClient.auto_login()

    function showToast(text) {
        toast.text = text;
        toastTimer.start();
    }
}
