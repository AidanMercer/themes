import QtQuick

// thicket: the songbird — frostify is the thing in the brush you can hear
// but not see. Leaf sprays bite the window's corners, and while a song runs
// a single dapple of warm light rests on one branch of the window. On every
// track change the bird MOVES: a quick rustle of loose leaves darts across
// the top of the window and the dapple lands somewhere else, then everything
// freezes again. Chrome + voice only; the layout stays frostify's own, and
// nothing animates unfocused or in silence.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color ember: pal.neon
    readonly property color iris: pal.cyan
    readonly property color dapple: pal.amber
    function emberA(a)  { return Qt.rgba(ember.r, ember.g, ember.b, a) }
    function irisA(a)   { return Qt.rgba(iris.r, iris.g, iris.b, a) }
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 313) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: foliage glass, leaf-dark lip
    readonly property color cardBorder: Qt.alpha(pal.dim, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    // the bird's voice
    readonly property string statusPlaying: "♪ IT SINGS"
    readonly property string statusPaused: "… HUSHED"
    readonly property string statusStopped: "■ FLOWN"
    readonly property string wordmark: "❧ the songbird"
    readonly property string glyphPrev: "◂◂"
    readonly property string glyphPlay: "▸"
    readonly property string glyphPause: "▮▮"
    readonly property string glyphNext: "▸▸"
    readonly property string glyphNowPlaying: "❧"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "✳"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // ── corner leaf sprays — one draw ──────────────────────────────
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
                    // anchored fans in three corners; the fourth stays open
                    const fans = [
                        { x: 0, y: 0, a0: 0.15, n: 6 },
                        { x: w, y: h * 0.9, a0: Math.PI + 0.2, n: 5 },
                        { x: w * 0.12, y: h, a0: -0.9, n: 4 }
                    ]
                    let s = 0
                    for (const fan of fans) {
                        for (let i = 0; i < fan.n; i++) {
                            s++
                            const ang = fan.a0 + (i / fan.n) * 1.3 + (chrome.rnd(s * 7) - 0.5) * 0.3
                            const len = 26 + chrome.rnd(s * 13) * 30
                            const wid = 7 + chrome.rnd(s * 17) * 6
                            const r = chrome.rnd(s * 41)
                            const fill = r < 0.3 ? "rgba(23,44,38,0.85)"
                                       : r < 0.5 ? "rgba(13,19,16,0.88)"
                                       : "rgba(5,9,7,0.9)"
                            leafShape(ctx, fan.x, fan.y, len, wid, ang, fill)
                        }
                    }
                }
            }

            // ── the dapple where the bird sits — lands elsewhere per track ──
            Canvas {
                id: perch
                width: 200; height: 120
                property int seed: 0
                x: 30 + chrome.rnd(seed * 7 + 2) * (bd.width - 260)
                y: 40 + chrome.rnd(seed * 13 + 6) * (bd.height * 0.5)
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                opacity: chrome.playing ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: 500 } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width / 2, height / 2, 4, width / 2, height / 2, width / 2)
                    g.addColorStop(0, String(chrome.dappleA(0.12)))
                    g.addColorStop(0.6, String(chrome.dappleA(0.05)))
                    g.addColorStop(1, String(chrome.dappleA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }

            // ── the rustle: loose leaves dart across the top on track change ─
            Item {
                id: rustle
                property real t: -1
                visible: t >= 0
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real ph: index * 0.14
                        readonly property real k: Math.max(0, Math.min(1, rustle.t - ph))
                        x: -30 + (bd.width + 60) * k
                        y: 26 + index * 15 + Math.sin(k * Math.PI * 2 + index) * 9
                        width: 9 - index; height: 3.5; radius: 1.75
                        rotation: k * 500 * (index % 2 === 0 ? 1 : -1)
                        opacity: rustle.t < 0 ? 0 : (k <= 0 || k >= 1 ? 0 : 0.85)
                        color: index === 1 ? "rgba(35,66,58,0.9)" : Qt.rgba(0.05, 0.08, 0.07, 0.9)
                    }
                }
                NumberAnimation {
                    id: rustleAnim
                    target: rustle; property: "t"
                    from: 0; to: 1.5; duration: 900
                    easing.type: Easing.OutQuad
                    onStopped: rustle.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() {
                    if (!chrome.awake) return
                    perch.seed = (perch.seed + 1) % 991
                    rustleAnim.restart()
                }
            }
        }
    }
}
