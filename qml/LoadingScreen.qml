// LoadingScreen.qml — splash screen shown during initial sync.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MatrixClient

Rectangle {
    id: loadingRoot
    color: Theme.windowBg

    property string stageText: Tr.tr(Theme.language, "Connecting\u2026")

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        // App title
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr(Theme.language, "Rustrix")
            color: Theme.sidebarFg
            font.pixelSize: Theme.fontSizeXl * 1.5
            font.bold: true
        }

        // Animated progress bar (indeterminate shimmer)
        Rectangle {
            id: loadingBar
            Layout.preferredWidth: 280
            Layout.preferredHeight: 4
            Layout.alignment: Qt.AlignHCenter
            color: Theme.border
            radius: 2
            clip: true

            Rectangle {
                id: progressFill
                height: parent.height
                radius: 2
                color: Theme.accent
                width: 100

                // Animated shimmer: slides left-to-right continuously
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: -progressFill.width
                        to: loadingBar.width
                        duration: 1800
                        easing.type: Easing.InOutCubic
                    }
                }
            }
        }

        // Stage text (what's currently happening)
        Label {
            id: stageLabel
            Layout.alignment: Qt.AlignHCenter
            text: loadingRoot.stageText
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // Update stage text based on MatrixClient state.
    // Also listen for syncDone (proven to arrive) as the primary
    // trigger to show "Ready!" — busyChanged/readyChanged via
    // queued_callback have been unreliable.
    Connections {
        target: MatrixClient
        function onBusyChanged() {
            if (MatrixClient.busy) {
                loadingRoot.stageText = Tr.tr(Theme.language, "Synchronizing\u2026")
            }
        }
        function onReadyChanged() {
            if (MatrixClient.ready) {
                loadingRoot.stageText = Tr.tr(Theme.language, "Ready!")
            }
        }
        function onSyncDone(payload) {
            loadingRoot.stageText = Tr.tr(Theme.language, "Ready!")
        }
    }
}
