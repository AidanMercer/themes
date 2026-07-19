import QtQuick

// thicket: foraging — the file manager is the watcher moving through the
// undergrowth, column by column. Leaf sprays hold the window's corners and a
// thin stem runs under the top seam with a few leaflets on it. Every
// directory change is a DART to new cover: a scatter of loose leaves flicks
// across the seam and one dapple of light lands somewhere new over the
// columns, then the brush freezes again. Chrome + voice only; the
// miller-columns layout stays mica's own. Nothing animates unfocused.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // mica window — active (focus), navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color dapple: pal.amber
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 127) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: foliage glass, leaf-dark lip
    readonly property color cardBorder: Qt.alpha(pal.dim, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    readonly property string wordmark: "❧ foraging"

    // the seam under mica's header band
    readonly property int seamY: 40

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the stem along the seam, with leaflets — one static draw
            Canvas {
                id: stem
                anchors.left: parent.left
                anchors.right: parent.right
                y: chrome.seamY
                height: 14
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    ctx.strokeStyle = String(chrome.leafA(0.5))
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(10, 4)
                    ctx.quadraticCurveTo(width * 0.5, 7, width - 10, 4)
                    ctx.stroke()
                    // leaflets along it
                    for (let i = 0; i < 7; i++) {
                        const x = width * (0.08 + i * 0.14)
                        const up = i % 2 === 0
                        ctx.save()
                        ctx.translate(x, 4 + (up ? 0 : 2)); ctx.rotate(up ? -0.6 : 0.7)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(5, -3.2, 11, -0.8)
                        ctx.quadraticCurveTo(5.2, 2.6, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = i % 3 === 0 ? "rgba(35,66,58,0.8)" : String(chrome.leafA(0.85))
                        ctx.fill()
                        ctx.restore()
                    }
                }
            }

            // corner leaf sprays — one draw
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
                    const fans = [
                        { x: -2, y: h * 0.85, a0: -0.7, n: 5 },
                        { x: w + 2, y: h * 0.2, a0: Math.PI - 0.6, n: 5 },
                        { x: w * 0.85, y: h + 2, a0: -2.3, n: 4 }
                    ]
                    let s = 0
                    for (const fan of fans) {
                        for (let i = 0; i < fan.n; i++) {
                            s++
                            const ang = fan.a0 + (i / fan.n) * 1.2 + (chrome.rnd(s * 7) - 0.5) * 0.3
                            const len = 22 + chrome.rnd(s * 13) * 28
                            const wid = 6 + chrome.rnd(s * 17) * 6
                            const r = chrome.rnd(s * 41)
                            const fill = r < 0.3 ? "rgba(23,44,38,0.85)"
                                       : r < 0.5 ? "rgba(13,19,16,0.88)"
                                       : "rgba(5,9,7,0.9)"
                            leafShape(ctx, fan.x, fan.y, len, wid, ang, fill)
                        }
                    }
                }
            }

            // the dapple over the columns — lands somewhere new on every nav
            Canvas {
                id: patch
                width: 230; height: 130
                property int seed: chrome.navSeed
                x: 20 + chrome.rnd(seed * 7 + 2) * Math.max(40, bd.width - 280)
                y: chrome.seamY + 20 + chrome.rnd(seed * 13 + 6) * Math.max(30, bd.height * 0.45)
                Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 230; easing.type: Easing.OutQuint } }
                opacity: 0.9
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width / 2, height / 2, 4, width / 2, height / 2, width / 2)
                    g.addColorStop(0, String(chrome.dappleA(0.10)))
                    g.addColorStop(0.6, String(chrome.dappleA(0.04)))
                    g.addColorStop(1, String(chrome.dappleA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── the dart to new cover: loose leaves flick along the seam on nav ─────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: scatter
                property real t: -1
                visible: t >= 0
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property real ph: index * 0.11
                        readonly property real k: Math.max(0, Math.min(1, scatter.t - ph))
                        x: -24 + (ov.width + 48) * k
                        y: chrome.seamY - 6 + index * 6 + Math.sin(k * Math.PI * 2 + index * 2) * 7
                        width: 8 - (index % 3); height: 3; radius: 1.5
                        rotation: k * 460 * (index % 2 === 0 ? 1 : -1)
                        opacity: scatter.t < 0 ? 0 : (k <= 0 || k >= 1 ? 0 : 0.8)
                        color: index % 3 === 0 ? "rgba(35,66,58,0.9)" : Qt.rgba(0.05, 0.08, 0.07, 0.9)
                    }
                }
                NumberAnimation {
                    id: scatterAnim
                    target: scatter; property: "t"
                    from: 0; to: 1.4; duration: 760
                    easing.type: Easing.OutQuad
                    onStopped: scatter.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) scatterAnim.restart() }
            }
        }
    }

    // move the dapple with the same nav event (backdrop-side connection)
    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        function onNavIdChanged() { chrome.navSeed = (chrome.navSeed + 1) % 991 }
    }
    property int navSeed: 0
}
