import QtQuick
import QtQuick.Effects
import Quickshell

// avalon: bare lock (the bareLock marker tells LockStage we own the chrome).
// The wallpaper video keeps playing full-bleed and sharp; a moss-glass panel
// on the left blurs the flowers behind it and carries the time, the passcode
// dots and a slow fall of petals. The gold seam draws down its edge as the
// lock engages, and everything rides host.progress so unlock plays it back.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color ivory: pal.text
    readonly property color blue:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color moss:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string serif: "Noto Serif Display"
    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function mossA(a)  { return Qt.rgba(moss.r, moss.g, moss.b, a) }

    readonly property real panelW: Math.max(430 * ui, root.width * 0.30)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // the live video (or still), re-rendered so the panel can blur its slice
    ShaderEffectSource {
        id: slice
        sourceItem: root.host.backgroundItem
        sourceRect: Qt.rect(0, 0, root.panelW, root.height)
        live: true
        visible: false
    }

    Item {
        id: panel
        width: root.panelW
        height: parent.height
        opacity: root.p

        MultiEffect {
            anchors.fill: parent
            source: slice
            blurEnabled: true
            blur: 1.0
            blurMax: 46
            brightness: -0.14
            saturation: -0.12
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.mossA(0.60) }
                GradientStop { position: 1.0; color: root.mossA(0.34) }
            }
        }
        // gold seam, drawing down as the lock engages
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height * root.p
            color: root.goldA(0.55)
        }

        // petals sinking through the glass
        Repeater {
            model: 9
            Rectangle {
                id: fleck
                required property int index
                readonly property real seed: (index * 0.61803) % 1
                width: (4 + seed * 3) * root.ui
                height: width
                rotation: 45 + seed * 60
                color: index % 4 === 0 ? root.goldA(0.5) : root.ivoryA(0.22 + seed * 0.15)
                x: panel.width * ((seed * 7.13) % 0.9 + 0.05)
                opacity: root.p * 0.8

                NumberAnimation on y {
                    running: root.p > 0.2
                    loops: Animation.Infinite
                    from: -30 - fleck.seed * panel.height * 0.4
                    to: panel.height + 30
                    duration: 21000 + fleck.seed * 26000
                }
            }
        }

        // content slides in from the seam's shadow
        Item {
            anchors.fill: parent
            transform: Translate { x: -22 * (1 - root.p) }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(panel.height * 0.17)
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "a v a l o n"
                    color: root.goldA(0.85)
                    font.family: root.serif
                    font.pixelSize: Math.round(13 * root.ui)
                    font.letterSpacing: 9
                    font.italic: true
                }
                Text {
                    id: timeText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: root.ivory
                    font.family: root.serif
                    font.pixelSize: Math.round(92 * root.ui)
                    font.weight: Font.Light
                    font.letterSpacing: 3
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: timeText.width
                    height: 1
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * root.p
                        height: 1
                        color: root.goldA(0.45)
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text {
                        text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                        color: root.ivoryA(0.55)
                        font.family: "Noto Sans"
                        font.pixelSize: Math.round(12 * root.ui)
                        font.letterSpacing: 5
                    }
                    Rectangle {
                        width: 4; height: 4
                        rotation: 45
                        color: root.blue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                        color: root.ivoryA(0.55)
                        font.family: "Noto Sans"
                        font.pixelSize: Math.round(12 * root.ui)
                        font.letterSpacing: 5
                    }
                }
            }

            // ── passcode ────────────────────────────────────────────────────
            Column {
                id: passArea
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(panel.height * 0.62)
                spacing: 18

                Row {
                    id: dots
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 13
                    opacity: root.host.pwLength > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Repeater {
                        model: Math.max(root.host.pwLength, 1)
                        Rectangle {
                            width: 8; height: 8
                            rotation: 45
                            color: root.host.failed ? root.rose : root.gold
                            opacity: index < root.host.pwLength ? 1 : 0
                            scale: root.host.busy ? 0.65 : 1
                            Behavior on scale { NumberAnimation { duration: 220 } }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: root.host.pwLength === 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    text: root.host.failed ? "wrong" : "enter passcode"
                    color: root.host.failed ? root.rose : root.ivoryA(0.45)
                    font.family: root.serif
                    font.pixelSize: Math.round(14 * root.ui)
                    font.italic: true
                    font.letterSpacing: 2
                }
            }
            // wrong password: the dots flinch
            Connections {
                target: root.host
                function onFailedChanged() { if (root.host.failed) shake.restart() }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -9; duration: 50 }
                NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
                NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -5; duration: 50 }
                NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 34
                text: "the ever-distant utopia"
                color: root.ivoryA(0.30)
                font.family: root.serif
                font.pixelSize: Math.round(11 * root.ui)
                font.italic: true
                font.letterSpacing: 3
            }
        }
    }
}
