import QtQuick
import Quickshell

// sailing: the ship's log — desktop clock for the "THROUGH SILENCE" wallpaper.
//
// Pinned upper-left in the open dusk sky, left of the girl and above the
// horizon. A log entry writes itself in: the vessel name types out, the time
// surfaces in thin serif numerals, a railing rule (two hairlines + stanchion
// posts — the theme's signature) draws underneath, then the instrument line
// "HDG 214° · 12.4 KN · LIGHT RAIN" and the watch line. Heading and knots
// drift almost imperceptibly like real instruments at sea, and the whole
// entry sways ±2px on one slow swell animation.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color buoy: pal.neon      // lifebuoy red-orange
    readonly property color dusk: pal.cyan      // lavender-pink sky
    readonly property color lamp: pal.amber     // brass / deck lamp
    readonly property color slate: pal.dim      // rain-gray slate
    readonly property color pale: pal.text      // lavender-white
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ship's watch, from the hour — the log's idea of "time of day"
    function watchName(h) {
        if (h < 4)  return "MIDDLE WATCH"
        if (h < 8)  return "MORNING WATCH"
        if (h < 12) return "FORENOON WATCH"
        if (h < 16) return "AFTERNOON WATCH"
        if (h < 20) return "DOG WATCH"
        return "FIRST WATCH"
    }

    // ── drifting instruments ────────────────────────────────────────────────
    // heading wanders around 214°, speed around 12.4 kn; new targets land
    // every 9s and ease over 5s — slow enough to feel like open water.
    property real heading: 214
    property real knots: 12.4
    Behavior on heading { NumberAnimation { duration: 5200; easing.type: Easing.InOutSine } }
    Behavior on knots   { NumberAnimation { duration: 5200; easing.type: Easing.InOutSine } }
    Timer {
        interval: 9000; running: true; repeat: true
        onTriggered: {
            root.heading = 214 + (Math.random() - 0.5) * 9
            root.knots = 12.4 + (Math.random() - 0.5) * 1.4
        }
    }

    // ── boot-in: the entry writes itself ────────────────────────────────────
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 2000; easing.type: Easing.OutCubic }
    function seg(from, to) { return Math.max(0, Math.min(1, (bootT - from) / (to - from))) }

    // ── the swell: one slow animation, ±2px ─────────────────────────────────
    property real sway: 0
    SequentialAnimation on sway {
        running: true; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 6500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 6500; easing.type: Easing.InOutSine }
    }

    Item {
        id: entry
        x: Math.round(root.width * 0.045)
        y: Math.round(root.height * 0.095) + (root.sway - 0.5) * 4 * root.ui
        width: col.width
        height: col.height
        opacity: 0.25 + 0.75 * root.bootT

        scale: root.ui
        transformOrigin: Item.TopLeft

        // a patch of deeper dusk behind the entry so pale text reads over the
        // bright sky — painted once, like the canopy's shadow reaching out
        Canvas {
            id: wash
            anchors.centerIn: col
            width: col.width + 260
            height: col.height + 200
            opacity: 0.62
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const g = ctx.createRadialGradient(width / 2, height / 2, 0,
                                                   width / 2, height / 2, Math.max(width, height) / 2)
                g.addColorStop(0, Qt.rgba(0.055, 0.075, 0.13, 0.72))
                g.addColorStop(0.65, Qt.rgba(0.055, 0.075, 0.13, 0.38))
                g.addColorStop(1, Qt.rgba(0.055, 0.075, 0.13, 0))
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Column {
            id: col
            spacing: Math.round(6)

            // vessel name, typing out — a small deck lamp keeps it company
            Row {
                spacing: 9
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: root.lamp
                    opacity: 0.4 + 0.5 * root.seg(0.0, 0.25)
                }
                Text {
                    readonly property string full: "M.V. THROUGH SILENCE — FERRY LOG"
                    text: full.substring(0, Math.round(root.seg(0.0, 0.55) * full.length))
                    color: root.duskA(0.92)
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 5
                }
            }

            // the time — thin serif numerals surfacing
            Text {
                id: timeText
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.pale
                opacity: root.seg(0.15, 0.5)
                font.family: root.serif
                font.pixelSize: 98
                font.weight: Font.Light
                font.letterSpacing: 4
                transform: Translate { y: 10 * (1 - root.seg(0.15, 0.5)) }
            }

            // the railing rule: two hairlines + stanchion posts, drawing in
            Item {
                id: railRule
                width: Math.round(timeText.width * root.seg(0.35, 0.75))
                height: 12
                clip: true
                Rectangle { y: 2; width: railRule.width; height: 1; color: root.paleA(0.55) }
                Rectangle { y: 8; width: railRule.width; height: 1; color: root.slateA(0.75) }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: index === 3 ? timeText.width - 2 : Math.round(timeText.width * index / 3)
                        y: 1
                        width: 2; height: 9
                        color: index === 0 ? root.buoy : root.paleA(0.65)
                    }
                }
            }

            // instrument line — degrees and knots gently adrift
            Text {
                opacity: root.seg(0.55, 0.85)
                text: "HDG " + ("00" + Math.round((root.heading + 360) % 360)).slice(-3) + "°"
                      + "   " + root.knots.toFixed(1) + " KN"
                      + "   LIGHT RAIN"
                color: root.duskA(0.85)
                font.family: root.mono
                font.pixelSize: 15
                font.letterSpacing: 4
            }

            // the watch line — date, and which watch has the bridge
            Text {
                opacity: root.seg(0.7, 1.0) * 0.8
                text: Qt.formatDateTime(clock.date, "ddd dd MMM").toUpperCase()
                      + "  ·  " + root.watchName(clock.date.getHours())
                color: root.duskA(0.7)
                font.family: root.mono
                font.pixelSize: 12
                font.letterSpacing: 4
            }
        }
    }
}
