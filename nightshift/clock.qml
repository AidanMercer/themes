import QtQuick
import Quickshell
import "windows.js" as W

// nightshift: the clock is a building. Its lit windows spell the hour, and the
// floors underneath carry residents of their own — a scatter of rooms that
// quietly changes as people turn in. When the minute turns, only the rooms
// that actually changed relight, room by room on the ripple, so the time
// arrives the way a real block changes: nobody flips a master switch.
//
// Sits upper-left, over the dark building wall on the wallpaper's left edge,
// clear of the figure at centre. Also drawn on the lock screen. Click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while locked or covered by a fullscreen window
    property bool occluded: false

    readonly property color sodium: pal.neon
    readonly property color haze: pal.cyan
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property real ui: pal.uiScale
    readonly property string sans: "Noto Sans"
    function inkA(a)  { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function hazeA(a) { return Qt.rgba(haze.r, haze.g, haze.b, a) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")

    // ── the block's geometry, in rooms ──────────────────────────────────────
    readonly property int glyphCols: W.textWidth("00:00", 1)   // 29 rooms
    readonly property int padX: 2
    readonly property int facadeCols: glyphCols + padX * 2
    readonly property int lowerRows: 4         // the floors where people live

    // the hour occupies the upper storeys on its own — the residents below are
    // drawn at half brightness so the one thing you're meant to READ is also
    // the brightest thing in the block (law 3: one warm room)
    readonly property var hourPlan: {
        const p = W.blank(facadeCols, W.glyphH())
        W.planText(p, facadeCols, W.glyphH(), hhmm, padX, 0, 1)
        return p
    }

    // the residents: a stable scatter, nudged now and then so the building is
    // never quite the same twice
    property var ambient: []
    function seedAmbient() {
        const a = []
        for (let i = 0; i < facadeCols * lowerRows; i++) a.push(Math.random() < 0.20 ? 1 : 0)
        ambient = a
    }
    Component.onCompleted: seedAmbient()

    Timer {
        // somebody turns in, somebody gets up
        interval: 21000; repeat: true; running: !root.occluded
        onTriggered: {
            const a = root.ambient.slice()
            if (!a.length) return
            for (let k = 0; k < 2; k++) {
                const i = Math.floor(Math.random() * a.length)
                a[i] = a[i] ? 0 : 1
            }
            root.ambient = a
        }
    }

    // ── placement: upper-left, over the wall, clear of the figure ───────────
    Item {
        id: block
        x: Math.round(root.width * 0.075)
        y: Math.round(root.height * 0.115)
        width: face.width
        height: dateLine.y + dateLine.height

        // the block has to defeat a video wallpaper, so it sits in its own
        // pocket of night rather than directly on the frame
        Rectangle {
            x: (face.width - width) / 2
            y: (parent.height - height) / 2
            width: face.width + 150 * root.ui
            height: parent.height + 110 * root.ui
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.012, 0.043, 0.086, 0.62) }
                GradientStop { position: 0.62; color: Qt.rgba(0.012, 0.043, 0.086, 0.30) }
                GradientStop { position: 1.0; color: Qt.rgba(0.012, 0.043, 0.086, 0.0) }
            }
            opacity: root.bootT
        }

        Facade {
            id: face
            cols: root.facadeCols
            rows: W.glyphH()
            cell: Math.round(13 * root.ui)
            gap: Math.round(4 * root.ui)
            lit: root.sodium
            dark: root.slate
            darkAlpha: 0.26
            occluded: root.occluded
            spread: 520                    // the hour takes its time to land
            plan: root.hourPlan
            opacity: root.bootT
        }

        // the residents' floors — same city, half the brightness, and a dark
        // service storey between them so the hour never runs into the lives
        Facade {
            id: lives
            anchors.top: face.bottom
            anchors.topMargin: Math.round((13 + 4) * root.ui)
            cols: root.facadeCols
            rows: root.lowerRows
            cell: Math.round(13 * root.ui)
            gap: Math.round(4 * root.ui)
            lit: root.sodium
            dark: root.slate
            darkAlpha: 0.26
            dim: 0.5
            occluded: root.occluded
            spread: 900                    // people turn in slowly
            plan: root.ambient
            opacity: root.bootT
        }

        // the street the block stands on
        Rectangle {
            anchors.top: lives.bottom
            anchors.topMargin: Math.round(9 * root.ui)
            width: face.width
            height: 1
            color: root.hazeA(0.34)
            opacity: root.bootT
        }

        Text {
            id: dateLine
            anchors.top: lives.bottom
            anchors.topMargin: Math.round(17 * root.ui)
            text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase()
            color: root.inkA(0.88)
            font.family: root.sans
            font.pixelSize: Math.round(15 * root.ui)
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            opacity: root.bootT
        }
    }

    // boot: the block comes up out of the haze
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 1100; easing.type: Easing.OutCubic }
}
