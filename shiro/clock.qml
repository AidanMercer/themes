import QtQuick
import Quickshell

// white: desktop clock, middle-left in the wallpaper's empty space.
// Quiet and editorial — thin serif time in ink violet, a hairline with a
// slow-drifting wisteria segment, a breathing blush dot in the date line.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // pushed live by the loader: true while locked or a fullscreen window covers this monitor
    property bool occluded: false

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot-in: rise + fade
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.width * 0.05)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Math.round(root.height * 0.04) + Math.round(16 * (1 - root.bootT))
        opacity: root.bootT
        spacing: 12

        scale: pal.uiScale
        transformOrigin: Item.TopLeft

        Text {
            text: "s  h  i  r  o"
            color: root.blush
            font.family: "Noto Sans"
            font.pixelSize: 12
            font.letterSpacing: 9
        }

        Text {
            id: timeText
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.ink
            font.family: "Noto Serif Display"
            font.pixelSize: 132
            font.weight: Font.Light
            font.letterSpacing: 2
        }

        // hairline with a slow wisteria drift
        Item {
            width: timeText.width
            height: 2

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 1
                color: root.inkA(0.14)
            }
            Rectangle {
                width: 56; height: 2; radius: 1
                color: root.wisteria
                opacity: 0.8
                SequentialAnimation on x {
                    running: !root.occluded; loops: Animation.Infinite
                    NumberAnimation { to: timeText.width - 56; duration: 9000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 9000; easing.type: Easing.InOutSine }
                }
            }
        }

        Row {
            spacing: 12

            Text {
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                color: root.inkA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 15
                font.letterSpacing: 6
            }
            Rectangle {
                width: 5; height: 5; radius: 2.5
                color: root.blush
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: !root.occluded; loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 2100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 2100; easing.type: Easing.InOutSine }
                }
            }
            Text {
                text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                color: root.inkA(0.55)
                font.family: "Noto Sans"
                font.pixelSize: 15
                font.letterSpacing: 6
            }
        }
    }
}
