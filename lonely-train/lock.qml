import QtQuick
import Quickshell

// lonely-train: bare lock (the bareLock marker tells LockStage we own the
// chrome). The wallpaper video keeps rolling full-bleed and sharp — the
// world still passing the windows — while the car doors slide in from both
// edges with lit amber seams. We draw our own departure board (top-left,
// same corner as the desktop clock) and the passcode as a route line where
// every keystroke lights the next station. A station plate bottom-right:
// NOW STOPPING AT · LOCKED. Everything rides host.progress so unlock plays
// the doors back open. Typing/Enter still route through the shell.
Item {
    id: root
    anchors.fill: parent

    // injected by LockStage (setSource initial properties)
    required property var pal
    required property var host
    readonly property bool bareLock: true

    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property real ui: pal.uiScale
    readonly property real p: host.progress
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property real doorW: root.width * 0.16

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // soft scrims top and bottom so the chrome reads over the bright video
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: parent.height * 0.26
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * 0.32
        opacity: root.p
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
        }
    }

    // a few faint lights drifting past, riding above the video's own motion
    Repeater {
        model: 5
        Item {
            id: mote
            required property int index
            readonly property real seed: (index * 0.61803) % 1
            readonly property real size: (26 + seed * 70) * root.ui
            width: size; height: size
            y: root.height * (0.08 + ((seed * 5.71) % 0.4))
            opacity: root.p * (0.08 + seed * 0.10)

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: mote.index % 2 === 0 ? root.amber : root.dusk
            }

            NumberAnimation on x {
                running: root.p > 0.2
                loops: Animation.Infinite
                from: root.width + 120
                to: -140
                duration: 13000 + mote.seed * 15000
            }
        }
    }

    // the doors: dark glass panels sliding in from both edges
    Repeater {
        model: 2
        Item {
            id: door
            required property int index
            readonly property bool leftDoor: index === 0
            width: root.doorW * root.p
            height: root.height
            x: leftDoor ? 0 : root.width - width

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: door.leftDoor ? root.glassA(0.9) : "transparent" }
                    GradientStop { position: 1.0; color: door.leftDoor ? "transparent" : root.glassA(0.9) }
                }
            }
            // the lit door edge + rubber seal
            Rectangle {
                width: 1.5
                height: parent.height
                x: door.leftDoor ? parent.width - 1.5 : 0
                color: root.amberA(0.7)
            }
            Rectangle {
                width: 3
                height: parent.height
                x: door.leftDoor ? parent.width - 5 : 2
                color: Qt.rgba(0, 0, 0, 0.5)
            }
            // door handle notch, mid-height
            Rectangle {
                width: 4; height: 46 * root.ui
                radius: 2
                x: door.leftDoor ? parent.width - 14 : 10
                y: parent.height * 0.5 - height / 2
                color: root.duskA(0.5)
            }
        }
    }

    // out-of-service line, up top where the ceiling lights are
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.065) - 12 * (1 - root.p)
        opacity: 0.65 * root.p
        text: "this train is out of service — please wait for the next one"
        color: root.inkA(0.85)
        font.family: root.serif
        font.pixelSize: Math.round(15 * root.ui)
        font.italic: true
        font.letterSpacing: 3
    }

    // ── the departure board, same corner as the desktop clock ──────────────
    component Flap: Item {
        id: cell
        property string ch: "0"
        property string _shown: ""
        width: Math.round(50 * root.ui)
        height: Math.round(74 * root.ui)
        Component.onCompleted: _shown = ch
        onChChanged: if (_shown !== ch) flip.restart()

        Rectangle {
            anchors.fill: parent
            radius: Math.round(7 * root.ui)
            color: root.glassA(0.85)
            border.width: 1
            border.color: root.inkA(0.10)
        }
        Text {
            anchors.centerIn: parent
            text: cell._shown
            color: root.inkA(0.95)
            font.family: root.mono
            font.pixelSize: Math.round(48 * root.ui)
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: Qt.rgba(0, 0, 0, 0.55)
        }
        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: 2; height: Math.round(7 * root.ui)
            color: root.inkA(0.25)
        }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 2; height: Math.round(7 * root.ui)
            color: root.inkA(0.25)
        }

        SequentialAnimation {
            id: flip
            NumberAnimation {
                target: flapY; property: "yScale"
                from: 1; to: 0; duration: 95; easing.type: Easing.InQuad
            }
            ScriptAction { script: cell._shown = cell.ch }
            NumberAnimation {
                target: flapY; property: "yScale"
                from: 0; to: 1; duration: 130; easing.type: Easing.OutBack
            }
        }
        transform: Scale { id: flapY; origin.y: cell.height / 2; yScale: 1 }
    }

    Column {
        x: Math.round(root.width * 0.065)
        y: Math.round(root.height * 0.16) + 16 * (1 - root.p)
        opacity: root.p
        spacing: Math.round(12 * root.ui)

        Row {
            spacing: Math.round(10 * root.ui)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(20 * root.ui); height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.amber
                Text {
                    anchors.centerIn: parent
                    text: "LT"
                    color: root.amber
                    font.family: root.mono
                    font.pixelSize: Math.round(8 * root.ui)
                    font.weight: Font.Black
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LAST TRAIN"
                color: root.amberA(0.92)
                font.family: root.mono
                font.pixelSize: Math.round(12 * root.ui)
                font.weight: Font.Bold
                font.letterSpacing: 6
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "· HELD AT PLATFORM"
                color: root.duskA(0.65)
                font.family: root.mono
                font.pixelSize: Math.round(9 * root.ui)
                font.letterSpacing: 3
            }
        }

        Row {
            spacing: Math.round(7 * root.ui)
            Flap { ch: root.hh[0] }
            Flap { ch: root.hh[1] }
            Item {
                width: Math.round(18 * root.ui); height: Math.round(74 * root.ui)
                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(13 * root.ui)
                    Rectangle { width: Math.round(5 * root.ui); height: width; radius: width / 2; color: root.amberA(0.85) }
                    Rectangle { width: Math.round(5 * root.ui); height: width; radius: width / 2; color: root.amberA(0.85) }
                }
            }
            Flap { ch: root.mm[0] }
            Flap { ch: root.mm[1] }
        }

        Row {
            spacing: Math.round(10 * root.ui)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                color: root.inkA(0.6)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 4
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(4 * root.ui); height: width
                radius: width / 2
                color: root.tail
                opacity: 0.8
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "MMMM dd").toUpperCase()
                color: root.inkA(0.6)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 4
            }
        }
    }

    // ── passcode: every keystroke lights the next station on the line ──────
    Item {
        id: passArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.15)
        width: Math.max(dotRow.width + 60 * root.ui, 200 * root.ui)
        height: Math.round(40 * root.ui)
        opacity: root.p

        // the rail, always there, grows with the typed stations
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 2
            color: root.host.failed ? Qt.rgba(root.tail.r, root.tail.g, root.tail.b, 0.55) : root.duskA(0.4)
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Row {
            id: dotRow
            anchors.centerIn: parent
            spacing: Math.round(17 * root.ui)
            Repeater {
                model: root.host.pwLength
                Rectangle {
                    width: Math.round(9 * root.ui); height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.host.failed ? root.tail : root.amber
                    border.width: 1.5
                    border.color: root.host.failed
                        ? Qt.rgba(root.tail.r, root.tail.g, root.tail.b, 0.5)
                        : root.amberA(0.5)
                    scale: root.host.busy ? 0.6 : 1
                    Behavior on scale { NumberAnimation { duration: 220 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        // hint when nothing is typed yet
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: Math.round(12 * root.ui)
            opacity: root.host.pwLength === 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            text: root.host.failed ? "wrong ticket — try again" : "enter passcode to board"
            color: root.host.failed ? root.tail : root.inkA(0.5)
            font.family: root.serif
            font.pixelSize: Math.round(13 * root.ui)
            font.italic: true
            font.letterSpacing: 2
        }
    }
    // wrong password: the line flinches
    Connections {
        target: root.host
        function onFailedChanged() { if (root.host.failed) shake.restart() }
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: -5; duration: 50 }
        NumberAnimation { target: passArea; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
    }

    // ── station plate, bottom-right at the platform's end ───────────────────
    Column {
        id: plate
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.width * 0.055)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.10) + 26 * (1 - root.p)
        opacity: root.p
        spacing: Math.round(9 * root.ui)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "NOW STOPPING AT"
            color: root.duskA(0.75)
            font.family: root.mono
            font.pixelSize: Math.round(10 * root.ui)
            font.letterSpacing: 6
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "L O C K E D"
            color: root.inkA(0.95)
            font.family: root.mono
            font.pixelSize: Math.round(24 * root.ui)
            font.weight: Font.Black
            font.letterSpacing: 4
        }

        // the route line: five stations, we're held at the middle one
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(180 * root.ui)
            height: Math.round(14 * root.ui)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * root.p
                height: 2
                color: root.duskA(0.5)
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    x: index / 4 * (parent.width - width)
                    width: Math.round((index === 2 ? 9 : 6) * root.ui)
                    height: width
                    radius: width / 2
                    color: index === 2 ? root.amber : "transparent"
                    border.width: 1.5
                    border.color: index === 2 ? root.amber : root.duskA(0.7)

                    // the here-dot breathes while held
                    SequentialAnimation on scale {
                        running: index === 2 && root.p > 0.5
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.35; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "doors will open on the right side"
            color: root.inkA(0.42)
            font.family: root.serif
            font.pixelSize: Math.round(11 * root.ui)
            font.italic: true
            font.letterSpacing: 2
        }
    }
}
