import QtQuick
import Quickshell
import Quickshell.Io

// lonely-train: departure-board clock, parked in the left window's dusk.
// Split-flap digit cells (each with the middle seam) under a LAST TRAIN
// station header; a route line with five station dots runs beneath, and on
// the minute a tiny train crosses it while the changed digits flap over.
// A REEL tape counter (system uptime) hums along the bottom. Also loaded on
// the lock screen over the blurred wallpaper — dark cells read fine there.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color amber: pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color tail:  pal.magenta
    readonly property color dim:   pal.dim
    readonly property color ink:   pal.text
    readonly property color glass: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hh: Qt.formatDateTime(clock.date, "HH")
    readonly property string mm: Qt.formatDateTime(clock.date, "mm")

    // uptime → the REEL counter, re-read once a minute
    property string reelText: "000:00"
    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: upProc.running = true
    }
    Process {
        id: upProc
        command: ["cat", "/proc/uptime"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.parseUptime(text) }
    }
    function parseUptime(raw) {
        const s = Math.floor(parseFloat(raw.trim().split(/\s+/)[0]) || 0)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        reelText = String(h).padStart(3, "0") + ":" + String(m).padStart(2, "0")
    }

    // boot-in: the board wakes up, cells flap in staggered, the line draws
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }

    // minute flourish: a tiny train crosses the route line
    property int _lastMin: -1
    Connections {
        target: clock
        function onDateChanged() {
            const m = clock.date.getMinutes()
            if (root._lastMin >= 0 && m !== root._lastMin && root.bootT >= 1)
                trainRun.restart()
            root._lastMin = m
        }
    }

    // one split-flap cell: dark slat, middle seam, flips when its digit turns
    component Flap: Item {
        id: cell
        property string ch: "0"
        property real delay: 0            // boot stagger 0..1
        property string _shown: ""
        width: Math.round(54 * root.ui)
        height: Math.round(80 * root.ui)
        opacity: Math.min(1, Math.max(0, (root.bootT - delay) / 0.4))
        Component.onCompleted: _shown = ch
        onChChanged: if (_shown !== ch) flip.restart()

        Rectangle {
            anchors.fill: parent
            radius: Math.round(7 * root.ui)
            color: root.glassA(0.82)
            border.width: 1
            border.color: root.inkA(0.10)
        }
        Item {
            id: face
            anchors.fill: parent
            transformOrigin: Item.Center
            Text {
                anchors.centerIn: parent
                text: cell._shown
                color: root.inkA(0.95)
                font.family: root.mono
                font.pixelSize: Math.round(52 * root.ui)
                font.weight: Font.DemiBold
            }
        }
        // the split-flap seam across the middle
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: Qt.rgba(0, 0, 0, 0.55)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            width: parent.width; height: 1
            color: root.inkA(0.06)
        }
        // side pivots
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
            // the flap folds shut…
            NumberAnimation {
                target: flapY; property: "yScale"
                from: 1; to: 0; duration: 95; easing.type: Easing.InQuad
            }
            ScriptAction { script: cell._shown = cell.ch }
            // …and the new digit unfolds with a slat overshoot
            NumberAnimation {
                target: flapY; property: "yScale"
                from: 0; to: 1; duration: 130; easing.type: Easing.OutBack
            }
        }
        transform: Scale { id: flapY; origin.y: cell.height / 2; yScale: 1 }
    }

    Column {
        id: board
        x: Math.round(root.width * 0.065)
        y: Math.round(root.height * 0.16) + Math.round(14 * (1 - root.bootT))
        spacing: Math.round(14 * root.ui)

        // header: line roundel + LAST TRAIN
        Row {
            spacing: Math.round(10 * root.ui)
            opacity: root.bootT

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(22 * root.ui); height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: root.amber
                Text {
                    anchors.centerIn: parent
                    text: "LT"
                    color: root.amber
                    font.family: root.mono
                    font.pixelSize: Math.round(9 * root.ui)
                    font.weight: Font.Black
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "LAST TRAIN"
                color: root.amberA(0.92)
                font.family: root.mono
                font.pixelSize: Math.round(13 * root.ui)
                font.weight: Font.Bold
                font.letterSpacing: 6
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "· DEPARTURES"
                color: root.duskA(0.6)
                font.family: root.mono
                font.pixelSize: Math.round(10 * root.ui)
                font.letterSpacing: 3
            }
        }

        // the flap time
        Row {
            spacing: Math.round(8 * root.ui)
            Flap { ch: root.hh[0]; delay: 0.05 }
            Flap { ch: root.hh[1]; delay: 0.15 }
            Item {
                width: Math.round(20 * root.ui); height: Math.round(80 * root.ui)
                opacity: Math.min(1, Math.max(0, (root.bootT - 0.2) / 0.4))
                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(14 * root.ui)
                    Rectangle { width: Math.round(5 * root.ui); height: width; radius: width / 2; color: root.amberA(0.85) }
                    Rectangle { width: Math.round(5 * root.ui); height: width; radius: width / 2; color: root.amberA(0.85) }
                }
            }
            Flap { ch: root.mm[0]; delay: 0.25 }
            Flap { ch: root.mm[1]; delay: 0.35 }
        }

        // route line: five stations, the boot draws it in; a little train
        // crosses on the minute
        Item {
            id: route
            width: flapsW; height: Math.round(16 * root.ui)
            readonly property real flapsW: Math.round((54 * 4 + 20 + 8 * 4) * root.ui)

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.bootT
                height: 2
                color: root.duskA(0.45)
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    x: index / 4 * (route.width - width)
                    width: Math.round(7 * root.ui); height: width
                    radius: width / 2
                    color: index === 4 ? root.amber : "transparent"
                    border.width: 2
                    border.color: index === 4 ? root.amber : root.duskA(0.7)
                    opacity: root.bootT >= (index / 4) * 0.9 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
            // the minute train: two lit cars sliding down the line
            Row {
                id: train
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Math.round(-6 * root.ui)
                spacing: 2
                opacity: 0
                Repeater {
                    model: 2
                    Rectangle {
                        width: Math.round(12 * root.ui); height: Math.round(5 * root.ui)
                        radius: 2
                        color: root.amber
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 6; height: 1
                            color: Qt.rgba(0, 0, 0, 0.5)
                        }
                    }
                }
            }
            SequentialAnimation {
                id: trainRun
                ParallelAnimation {
                    NumberAnimation { target: train; property: "x"; from: -30 * root.ui; to: route.flapsW + 4 * root.ui; duration: 1900; easing.type: Easing.InOutSine }
                    SequentialAnimation {
                        NumberAnimation { target: train; property: "opacity"; to: 1; duration: 200 }
                        PauseAnimation { duration: 1300 }
                        NumberAnimation { target: train; property: "opacity"; to: 0; duration: 400 }
                    }
                }
            }
        }

        // destination row: serif poetry + the date plate
        Row {
            spacing: Math.round(12 * root.ui)
            opacity: root.bootT
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "bound for home"
                color: root.inkA(0.62)
                font.family: root.serif
                font.pixelSize: Math.round(15 * root.ui)
                font.italic: true
                font.letterSpacing: 2
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(5 * root.ui); height: width
                radius: width / 2
                color: root.tail
                opacity: 0.8
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd · MMM dd").toUpperCase()
                color: root.duskA(0.75)
                font.family: root.mono
                font.pixelSize: Math.round(11 * root.ui)
                font.letterSpacing: 4
            }
        }

        // the tape counter, quietly spinning since boot
        Row {
            spacing: Math.round(7 * root.ui)
            opacity: 0.75 * root.bootT
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(6 * root.ui); height: width
                radius: width / 2
                color: root.tail
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REEL " + root.reelText
                color: root.inkA(0.45)
                font.family: root.mono
                font.pixelSize: Math.round(10 * root.ui)
                font.letterSpacing: 3
            }
        }
    }
}
