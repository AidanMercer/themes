import QtQuick

// thicket: the hide — reading in deep cover. The editor is where the watcher
// lies flattest: while a PAGE is up, two dapples of canopy light lie across
// it and leaf sprays hold the margins; while you TYPE, nothing moves at all
// — no light, no leaves stirring, dead still (the reading gate, verbatim).
// When a page composes, the canopy shifts once: a soft band of light sweeps
// down the window in one motion and the dapples settle somewhere new. That
// sweep is the only event this file owns. Everything sits BEHIND the panes.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    // the reading gate — the only thing that may animate is `stirring`
    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color dapple: pal.amber
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 557) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: foliage glass, leaf-dark lip
    readonly property color cardBorder: Qt.alpha(pal.dim, 0.6)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    property int pageSeed: 0

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // ── margin sprays: leaves holding the window's edges — one draw ─
            Canvas {
                id: sprays
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                function leafShape(ctx, x, y, len, wid, ang, fill) {
                    ctx.save()
                    ctx.translate(x, y); ctx.rotate(ang)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                    ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                    ctx.closePath()
                    ctx.fillStyle = fill
                    ctx.fill()
                    ctx.restore()
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height
                    // left and right margins, sparse — the page owns the middle
                    for (let i = 0; i < 12; i++) {
                        const left = i < 6
                        const f = (left ? i : i - 6) / 6
                        const x = left ? -2 : w + 2
                        const y = h * (0.1 + f * 0.85) + (chrome.rnd(i * 7) - 0.5) * 30
                        const ang = (left ? 0 : Math.PI) + (chrome.rnd(i * 3) - 0.5) * 1.1
                        const r = chrome.rnd(i * 41)
                        const fill = r < 0.3 ? "rgba(23,44,38,0.8)"
                                   : r < 0.5 ? "rgba(13,19,16,0.85)"
                                   : "rgba(5,9,7,0.88)"
                        leafShape(ctx, x, y, 20 + chrome.rnd(i * 13) * 26, 6 + chrome.rnd(i * 17) * 5, ang, fill)
                    }
                }
            }

            // ── the dapples on the page — lit only while reading ────────────
            Repeater {
                model: 2
                Canvas {
                    id: pd
                    required property int index
                    width: 260; height: 150
                    readonly property int seed: chrome.pageSeed * 2 + index
                    x: 40 + chrome.rnd(seed * 7 + 2) * Math.max(40, bd.width - 340)
                    y: 30 + chrome.rnd(seed * 13 + 6) * Math.max(30, bd.height * 0.6)
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    opacity: chrome.page ? 0.9 : 0
                    Behavior on opacity { NumberAnimation { duration: 450 } }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const g = ctx.createRadialGradient(width / 2, height / 2, 4, width / 2, height / 2, width / 2)
                        g.addColorStop(0, String(chrome.dappleA(0.08)))
                        g.addColorStop(0.6, String(chrome.dappleA(0.035)))
                        g.addColorStop(1, String(chrome.dappleA(0)))
                        ctx.fillStyle = g
                        ctx.fillRect(0, 0, width, height)
                    }
                    Component.onCompleted: requestPaint()
                }
            }

            // ── the canopy shifts: one band of light sweeps down on compose ─
            Rectangle {
                id: sweep
                property real t: -1
                visible: t >= 0
                width: bd.width
                height: 90
                y: -90 + (bd.height + 180) * Math.max(0, t)
                opacity: t < 0 ? 0 : Math.sin(Math.min(1, t) * Math.PI) * 0.8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: chrome.dappleA(0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                NumberAnimation {
                    id: sweepAnim
                    target: sweep; property: "t"
                    from: 0; to: 1; duration: 620
                    easing.type: Easing.OutQuad
                    onStopped: sweep.t = -1
                }
            }
            // fire on the page composing — gated on `page`, NOT `stirring`,
            // so alt-tabbing back doesn't re-fire the flourish
            Connections {
                target: chrome
                function onPageChanged() {
                    if (chrome.page) {
                        chrome.pageSeed = (chrome.pageSeed + 1) % 991
                        if (chrome.stirring) sweepAnim.restart()
                    }
                }
            }
        }
    }
}
