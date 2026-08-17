// LoadingScreen.qml — splash screen shown during initial sync.
import QtQuick
import QtQuick.Controls
import MatrixClient

Rectangle {
    id: loadingRoot
    color: Theme.windowBg

    property string stageText: qsTr("Connecting\u2026")

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        // App title
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Matrix Client")
            color: Theme.sidebarFg
            font.pixelSize: Theme.fontSizeXl * 1.5
            font.bold: true
        }

        // Animated progress bar
        Rectangle {
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
                width: 100
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

    // Update stage text based on MatrixClient state
    Connections {
        target: MatrixClient
        function onBusyChanged() {
            if (MatrixClient.busy) {
                loadingRoot.stageText = qsTr("Synchronizing\u2026")
            } else if (MatrixClient.ready) {
                loadingRoot.stageText = qsTr("Ready!")
            }
        }
        function onReadyChanged() {
            if (MatrixClient.ready) {
                loadingRoot.stageText = qsTr("Ready!")
            }
        }
    }
}
