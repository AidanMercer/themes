import QtQuick
import Quickshell.Io

// gunsmoke: the visualizer is not bars — it is a FOG BANK along the bottom
// of the screen, lit from within. Each frequency bin is a lantern-glow bloom
// inside the murk; the whole bank breathes with the mix. A hard bass
// transient fires a MUZZLE FLASH deep in the fog — one bright bloom that
// decays like an afterimage — and only the very hottest shot shows a
// heartbeat of oxblood at its core (the withheld accent, spent on a kill).
// At silence the fog goes dark bloom by bloom, the canvas stops painting,
// and the cava process itself is parked (feed gate below). Click-through.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    // pushed by the loader after mount: lock/fullscreen cover + mpris playing
    property bool occluded: false
    property bool playing: true
    readonly property bool feedOn: playing && !occluded

    readonly property color bone: pal.neon
    readonly property color steel: pal.cyan
    readonly property color blood: pal.magenta
    function boneA(a)  { return Qt.rgba(bone.r, bone.g, bone.b, a) }
    function steelA(a) { return Qt.rgba(steel.r, steel.g, steel.b, a) }
    function colA(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    readonly property int bins: 24

    property var levels: []       // raw cava bins 0..1
    property var display: []      // smoothed values
    property bool humming: false

    // muzzle flash state: energy 0..1 decaying, position in bin space
    property real flash: 0
    property real flashX: 0.3
    property real bassPrev: 0

    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }

    Component.onCompleted: {
        const d = []
        for (let i = 0; i < bins; i++) d.push(0)
        display = d
    }

    Process {
        id: cava
        running: root.feedOn
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
        onRunningChanged: if (root.feedOn && !running) cavaRestart.start()
    }
    Timer {
        id: cavaRestart
        interval: 2000
        // re-assign the binding, not `= true`, or one crash restart would strip
        // the feed gate and leak the reader forever
        onTriggered: cava.running = Qt.binding(() => root.feedOn)
    }

    property double lastFrameMs: 0

    function parseFrame(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "") continue
            out.push(Math.min(1, parseInt(parts[i]) / 1000))
        }
        if (out.length) {
            root.levels = out
            root.lastFrameMs = Date.now()
            if (!tick.running) tick.start()
        }
    }

    // smoothing + flash physics — stops itself once frames go stale and the
    // whole bank has gone dark, so silence costs nothing.
    Timer {
        id: tick
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const d = root.display, l = root.levels
            let loud = 0, settled = true
            for (let i = 0; i < root.bins; i++) {
                let t = l[i] || 0
                if (t < 0.04) t = 0
                d[i] = d[i] + (t - d[i]) * 0.35
                if (d[i] < 0.005) d[i] = 0
                if (d[i] > loud) loud = d[i]
                if (d[i] > 0.004) settled = false
            }

            // the shot: a hard jump in the low bins fires the flash
            let bass = 0
            for (let i = 0; i < 5; i++) bass += (l[i] || 0)
            bass /= 5
            if (bass - root.bassPrev > 0.32 && bass > 0.55 && root.flash < 0.25) {
                root.flash = Math.min(1, bass)
                // land it deep in the low-mid fog, seeded off the clock
                root.flashX = 0.12 + ((Date.now() % 977) / 977) * 0.5
            }
            root.bassPrev = bass
            root.flash = root.flash * 0.86
            if (root.flash < 0.02) root.flash = 0
            if (root.flash > 0) settled = false

            const now = Date.now()
            const audioActive = loud > 0.05
            if (audioActive) root.lastFrameMs = now

            const nowHumming = audioActive || !settled
            if (nowHumming !== root.humming) root.humming = nowHumming

            fog.requestPaint()
            if (!nowHumming && now - root.lastFrameMs > 2000) tick.stop()   // cava asleep
        }
    }

    // ── the fog bank ────────────────────────────────────────────────────────
    Canvas {
        id: fog
        width: root.width
        height: Math.round(root.height * 0.30)
        anchors.bottom: parent.bottom

        opacity: root.bootT * (root.humming ? 1 : 0)
        visible: opacity > 0.01
        // smoke law: the fog takes longer to leave than to arrive
        Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const d = root.display
            const colW = w / root.bins

            // each bin: a lantern glow low in the murk, radius and heat by level
            for (let i = 0; i < root.bins; i++) {
                const v = d[i]
                if (v <= 0.01) continue
                const cx = (i + 0.5) * colW
                const cy = h + 30
                const r = 60 + v * h * 1.25
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                const hot = v > 0.85
                g.addColorStop(0, String(root.boneA(0.05 + v * 0.16)))
                g.addColorStop(0.5, String(root.steelA(0.03 + v * 0.06)))
                g.addColorStop(1, String(root.steelA(0)))
                ctx.fillStyle = g
                ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
                if (hot) {   // the bank's crown catches light
                    const g2 = ctx.createRadialGradient(cx, cy, 0, cx, cy, r * 0.4)
                    g2.addColorStop(0, String(root.boneA(0.10)))
                    g2.addColorStop(1, String(root.boneA(0)))
                    ctx.fillStyle = g2
                    ctx.fillRect(cx - r, cy - r, r * 2, r * 2)
                }
            }

            // the muzzle flash: one bright bloom deep in the fog, decaying
            if (root.flash > 0.02) {
                const fx = root.flashX * w
                const fy = h * 0.72
                const fr = 90 + root.flash * 260
                const g = ctx.createRadialGradient(fx, fy, 0, fx, fy, fr)
                g.addColorStop(0, String(root.boneA(0.34 * root.flash)))
                g.addColorStop(0.35, String(root.boneA(0.12 * root.flash)))
                g.addColorStop(1, String(root.boneA(0)))
                ctx.fillStyle = g
                ctx.fillRect(fx - fr, fy - fr, fr * 2, fr * 2)
                // only the hottest shot bleeds — the withheld accent, spent
                if (root.flash > 0.9) {
                    const g2 = ctx.createRadialGradient(fx, fy, 0, fx, fy, 40)
                    g2.addColorStop(0, String(root.colA(root.blood, 0.30)))
                    g2.addColorStop(1, String(root.colA(root.blood, 0)))
                    ctx.fillStyle = g2
                    ctx.fillRect(fx - 40, fy - 40, 80, 80)
                }
            }
        }
    }
}
