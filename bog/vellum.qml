import QtQuick

// bog: reading on the raft. The text column owns the window; the pond only
// shows at its edges — a patch of noon light settles over the page while
// you read, and a dim waterline with a few glints runs along the very
// bottom. The reading gate is strict: while a page is up in a focused
// window one slow ring drifts on the water now and then; the moment you
// start typing (or look away) the pond holds perfectly still. When a page
// composes, the pond takes the book's weight: one ring blooms low in the
// window and settles — that's the page turn, spoken in water.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    // chassis: pebble-smooth glass with a moss lip
    readonly property color cardBorder: Qt.alpha(moss, 0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real waterY: height - 26

            // the patch of noon: a warm pool settling over the page while
            // you read (one state fade, then perfectly still)
            Canvas {
                id: noon
                width: Math.min(420, bd.width * 0.6)
                height: 150
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: chrome.page ? 0.35 : 0
                Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const a = width / 2
                    ctx.save()
                    ctx.scale(1, height / a)
                    const g = ctx.createRadialGradient(a, 0, 0, a, 0, a)
                    g.addColorStop(0, String(chrome.sunA(0.13)))
                    g.addColorStop(1, String(chrome.sunA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, a)
                    ctx.restore()
                }
                Component.onCompleted: requestPaint()
            }

            // the waterline at the very bottom, dim — the pond is far away
            // while you work
            Rectangle {
                x: 10; y: bd.waterY
                width: parent.width - 20
                height: 1
                color: chrome.reedA(0.35)
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: 26 + index * ((bd.width - 64) / 5)
                    y: bd.waterY - 1
                    width: index % 2 === 0 ? 14 : 7
                    height: 2
                    radius: 1
                    color: chrome.sunA(0.14)
                }
            }

            // one slow ring drifting on the water while you read
            Canvas {
                id: drift
                property real t: 0
                x: bd.width * 0.3
                y: bd.waterY - 10
                width: 76; height: 22
                onTChanged: requestPaint()
                SequentialAnimation on t {
                    running: chrome.stirring && bd.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 3400 }
                    NumberAnimation { from: 0; to: 1; duration: 5200 }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const tt = t
                    if (tt <= 0 || tt >= 1) return
                    const r = (width / 2) * (0.1 + 0.9 * tt)
                    ctx.save()
                    ctx.translate(width / 2, height * 0.7)
                    ctx.scale(1, 0.3)
                    ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.strokeStyle = String(chrome.sunA(0.15 * (1 - tt)))
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
            }

            // ── the page turn: the pond takes the book's weight ─────────────
            Canvas {
                id: turn
                property real t: -1
                visible: t >= 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: bd.waterY - 20
                width: 200; height: 44
                onTChanged: requestPaint()
                NumberAnimation {
                    id: turnAnim
                    target: turn; property: "t"
                    from: 0; to: 1; duration: 2200; easing.type: Easing.OutSine
                    onStopped: turn.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 3; k++) {
                        const tt = (t - k * 0.18) / (1 - k * 0.18)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.08 + 0.92 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.24)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.28 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 1.8 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            // gate on `page`, NOT `stirring` — alt-tabbing must not re-fire
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) turnAnim.restart() }
            }
        }
    }
}
