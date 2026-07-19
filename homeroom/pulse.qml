import QtQuick
import "chalk.js" as Chalk

// homeroom: the health check. The system monitor gets the classroom's
// weather report, drawn in chalk in the top-right corner: a morning sun
// whose rays reach further as the CPU warms up (and flush stripe-pink when
// it's running hot), and a little cloud beside it that hatches itself in as
// memory fills. Both are quantized — the chalk redraws on whole steps, not
// every jitter of the load. Re-sorting the table underlines the header in
// chalk; actually killing a process brings THE ERASER across the whole
// window with a pink flash — erasing a name from the board is the scariest
// thing this room can do. No input handlers; still when unfocused.
Item {
    id: chrome

    required property var pal   // snapshot palette (halo/periwinkle/pink…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real memLoad: host && host.memLoad !== undefined ? host.memLoad : 0

    readonly property color chalk: pal.text
    readonly property color pink: pal.magenta
    readonly property color sun: pal.amber
    function chalkA(a) { return Qt.rgba(chalk.r, chalk.g, chalk.b, a) }
    function sunA(a)   { return Qt.rgba(sun.r, sun.g, sun.b, a) }

    // chassis: paper-soft corners, a faint chalk lip
    readonly property color cardBorder: Qt.alpha(chalk, 0.22)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "☼ health check"

    // quantized weather — the chalk only redraws on whole steps
    readonly property int sunStep: Math.round(load * 8)
    readonly property int cloudStep: Math.round(memLoad * 6)

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // chalk corner ticks, the room's quiet frame
            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const c = String(chrome.chalkA(1))
                    Chalk.strokePath(ctx, [[10, 34], [10, 10], [34, 10]],
                        { seed: 1601, color: c, alpha: 0.22, width: 2, ghost: false, dust: 0.04 })
                    Chalk.strokePath(ctx, [[width - 10, height - 34], [width - 10, height - 10], [width - 34, height - 10]],
                        { seed: 1607, color: c, alpha: 0.22, width: 2, ghost: false, dust: 0.04 })
                }
            }

            // ── the weather report, top-right ──────────────────────────────
            Canvas {
                id: weather
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 18
                anchors.topMargin: 12
                width: 150; height: 64
                property int sunQ: chrome.sunStep
                property int cloudQ: chrome.cloudStep
                onSunQChanged: requestPaint()
                onCloudQChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const hot = sunQ >= 7
                    const sc = hot ? String(Qt.rgba(chrome.pink.r, chrome.pink.g, chrome.pink.b, 1))
                                   : String(chrome.sunA(1))
                    // the sun: a chalk circle at the right
                    const sx = 116, sy = 32, r0 = 13
                    Chalk.strokePath(ctx, [[sx + r0, sy], [sx + r0 * 0.7, sy - r0 * 0.7], [sx, sy - r0],
                                           [sx - r0 * 0.7, sy - r0 * 0.7], [sx - r0, sy], [sx - r0 * 0.7, sy + r0 * 0.7],
                                           [sx, sy + r0], [sx + r0 * 0.7, sy + r0 * 0.7], [sx + r0, sy]],
                                     { seed: 1621, color: sc, alpha: 0.65, width: 2.2, ghost: false, dust: 0.05 })
                    // rays: one per load step, reaching further as it climbs
                    const rays = Math.min(8, sunQ)
                    const reach = 6 + sunQ * 1.6
                    for (let i = 0; i < rays; i++) {
                        const a = -Math.PI / 2 + i * Math.PI * 2 / 8
                        Chalk.strokePath(ctx,
                            [[sx + Math.cos(a) * (r0 + 4), sy + Math.sin(a) * (r0 + 4)],
                             [sx + Math.cos(a) * (r0 + 4 + reach), sy + Math.sin(a) * (r0 + 4 + reach)]],
                            { seed: 1631 + i * 3 + sunQ, color: sc, alpha: 0.6, width: 2, ghost: false, dust: 0.04 })
                    }
                    // the memory cloud, hatching itself full
                    const cx = 34, cy = 36
                    Chalk.strokePath(ctx, [[cx - 22, cy + 8], [cx - 26, cy - 2], [cx - 16, cy - 10], [cx - 2, cy - 14],
                                           [cx + 12, cy - 9], [cx + 18, cy], [cx + 14, cy + 8], [cx - 22, cy + 8]],
                                     { seed: 1651, color: String(chrome.chalkA(1)), alpha: 0.45, width: 1.8, ghost: false, dust: 0.03 })
                    for (let i = 0; i < cloudQ; i++) {
                        Chalk.strokePath(ctx, [[cx - 18 + i * 6, cy + 5], [cx - 12 + i * 6, cy - 8]],
                            { seed: 1661 + i * 7, color: String(chrome.chalkA(1)), alpha: 0.35, width: 1.5, ghost: false, dust: 0 })
                    }
                }
            }
        }
    }

    // ── overlays: the underline, and THE ERASER ────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            // re-sort: chalk underline sweeps under the header row
            Item {
                id: sortLine
                x: 16
                y: 54
                width: ov.width * 0.4
                height: 8
                property real t: -1
                visible: t >= 0
                clip: true
                Canvas {
                    width: ov.width * 0.4
                    height: 8
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width <= 0) return
                        Chalk.strokePath(ctx, [[2, 4], [width - 2, 3]], {
                            seed: 1701, color: String(chrome.chalkA(1)), alpha: 0.5, width: 2.2, dust: 0.06
                        })
                    }
                    Component.onCompleted: requestPaint()
                }
            }
            Binding {
                target: sortLine
                property: "width"
                value: ov.width * 0.4 * Math.max(0, Math.min(1, sortLine.t * 1.4))
                when: sortLine.t >= 0
            }
            SequentialAnimation {
                id: sortSweep
                PropertyAction  { target: sortLine; property: "t"; value: 0 }
                NumberAnimation { target: sortLine; property: "t"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutQuad }
                PropertyAction  { target: sortLine; property: "t"; value: -1 }
            }

            // a kill: the eraser crosses the whole window
            Rectangle {   // the pink flash
                anchors.fill: parent
                color: Qt.rgba(chrome.pink.r, chrome.pink.g, chrome.pink.b, 0.10)
                opacity: 0
                id: flash
            }
            Item {
                id: eraser
                property real t: -1
                visible: t >= 0
                x: -80 + (ov.width + 160) * Math.max(0, t)
                y: ov.height * 0.35
                rotation: -8
                Rectangle {   // the smear it leaves
                    x: -70; y: 6
                    width: 120; height: 46
                    radius: 23
                    color: chrome.chalkA(0.08)
                }
                Rectangle {   // the felt block
                    width: 44; height: 19
                    radius: 2
                    color: chrome.pal.dim
                    Rectangle { width: parent.width; height: 6; radius: 2; color: chrome.chalkA(0.5) }
                }
            }
            SequentialAnimation {
                id: killWipe
                ParallelAnimation {
                    NumberAnimation { target: eraser; property: "t"; from: 0; to: 1; duration: 620; easing.type: Easing.InOutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: flash; property: "opacity"; from: 0; to: 1; duration: 120 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 480 }
                    }
                }
                PropertyAction { target: eraser; property: "t"; value: -1 }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) sortSweep.restart() }
                function onKillPulseChanged() { if (chrome.awake) killWipe.restart() }
            }
        }
    }
}
