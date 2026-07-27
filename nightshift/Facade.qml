import QtQuick
import "windows.js" as W

// nightshift: a block of rooms. Hand it a `plan` (a flat 0/1 array from one of
// windows.js's grammars) and the block relights itself room by room on the
// ripple — never as one flip. Owns exactly one Canvas and one 33ms timer that
// only runs while something is actually moving, so a settled facade is free.
//
// This is the theme's single rendering primitive: the clock, the bar gauges,
// the sysinfo board, the lock passcode and the overview chrome are all this
// component with a different plan.
Item {
    id: fac

    property int cols: 1
    property int rows: 1
    property real cell: 10               // a room, in px
    property real gap: 3                 // the mortar between rooms
    property color lit: "#c8dc9e"
    property color dark: "#2c4a7d"
    property real darkAlpha: 0.28        // unlit rooms are structure, not data
    property real dim: 1.0               // scales the whole block's brightness
    property bool occluded: false        // parks the timers (locked / covered)
    property bool flicker: true          // the rare sodium flutter
    property int spread: 380             // the ripple's scatter, ms
    property bool instant: false         // land the first plan with no ripple
    property var plan: null

    implicitWidth: Math.max(0, cols * (cell + gap) - gap)
    implicitHeight: Math.max(0, rows * (cell + gap) - gap)
    width: implicitWidth
    height: implicitHeight

    readonly property string litCss: String(Qt.rgba(lit.r, lit.g, lit.b, 1))
    readonly property string darkCss: String(Qt.rgba(dark.r, dark.g, dark.b, darkAlpha))

    property var cells: W.makeCells(1)
    property bool busy: false
    property bool anyLit: false
    property bool _seeded: false

    onColsChanged: _resize()
    onRowsChanged: _resize()
    function _resize() {
        cells = W.resizeCells(cells, Math.max(1, cols * rows))
        _seeded = false
        if (plan) light(plan)
    }

    // hand the block a new lighting plan
    function light(p) {
        if (!p || !p.length) return
        let any = false
        for (let i = 0; i < p.length; i++) if (p[i]) { any = true; break }
        anyLit = any
        if (instant && !_seeded) {
            W.setPlan(cells, p)
            _seeded = true
            canvas.requestPaint()
            return
        }
        _seeded = true
        W.applyPlan(cells, p, Date.now(), spread)
        busy = true
    }
    onPlanChanged: light(plan)
    Component.onCompleted: if (plan) light(plan)

    // repaint only while the city is still changing its mind
    Timer {
        id: anim
        interval: 33; repeat: true
        running: fac.busy && !fac.occluded && fac.visible
        onTriggered: {
            fac.busy = W.tick(fac.cells, Date.now())
            canvas.requestPaint()
        }
    }

    // one room, every couple of seconds, stutters like a tired sodium tube.
    // Deliberately an event and not a loop: it wakes the 33ms timer for ~400ms
    // and then the whole widget goes back to costing nothing.
    Timer {
        id: flick
        interval: 2400
        repeat: true
        running: fac.flicker && fac.anyLit && !fac.occluded && fac.visible
        onTriggered: {
            interval = 1500 + Math.round(Math.random() * 2600)
            if (Math.random() < 0.65 && W.flutter(fac.cells)) fac.busy = true
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            W.draw(ctx, fac.cells, fac.cols, fac.rows, fac.cell, fac.cell,
                   fac.gap, fac.darkCss, fac.litCss, fac.dim)
        }
    }

    // pal arrives async — recolour without waiting for a state change
    onLitCssChanged: canvas.requestPaint()
    onDarkCssChanged: canvas.requestPaint()
    onDimChanged: canvas.requestPaint()
}
