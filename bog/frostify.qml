import QtQuick

// bog: the pond sings. The player floats on the pond — a waterline runs low
// across the window with sun-glints riding it, reed silhouettes stand in the
// bottom corners, and while the music plays slow ripple rings drift out
// across the water. On every track change a FISH JUMPS: a small sunlit arc
// clears the waterline and goes back under with a splash of rings. Chrome +
// voice only; the layout stays frostify's own; everything holds still when
// the window isn't looked at or the song rests.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color rust: pal.magenta
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    // deterministic hash — the same pond on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: pebble-smooth glass with a moss lip
    readonly property color cardBorder: Qt.alpha(moss, 0.35)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    // the pond's voice
    readonly property string statusPlaying: "≈ the pond sings"
    readonly property string statusPaused: "≈ resting on the oars"
    readonly property string statusStopped: "· still water"
    readonly property string wordmark: "≈ the songbook"
    readonly property string glyphPrev: "«"
    readonly property string glyphPlay: "▷"
    readonly property string glyphPause: "❙❙"
    readonly property string glyphNext: "»"
    readonly property string glyphNowPlaying: "≈"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "·"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real waterY: height - 64

            // the waterline with its glints
            Rectangle {
                x: 10; y: bd.waterY
                width: parent.width - 20
                height: 1
                color: chrome.reedA(0.5)
            }
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    x: 24 + index * ((bd.width - 60) / 6)
                    y: bd.waterY - 1
                    width: index % 2 === 0 ? 18 : 9
                    height: 2
                    radius: 1
                    color: chrome.sunA(0.22)
                }
            }
            // beneath the line the murk deepens
            Rectangle {
                x: 1; y: bd.waterY + 1
                width: parent.width - 2
                height: parent.height - bd.waterY - 2
                color: chrome.mossA(0.06)
            }

            // reed silhouettes in the bottom corners (still — the painting's)
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    readonly property bool leftBank: index < 4
                    x: leftBank ? 12 + index * 9 + chrome.rnd(index * 7) * 6
                                : bd.width - 48 + (index - 4) * 11
                    y: bd.waterY - height
                    width: 1.6
                    height: 26 + chrome.rnd(index * 13 + 3) * 26
                    radius: 1
                    rotation: (chrome.rnd(index * 29) - 0.5) * 10
                    color: chrome.reedA(0.75)
                    transformOrigin: Item.Bottom
                }
            }
            // a cattail head on two of them
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    x: (index === 0 ? 21 : bd.width - 37) + index * 2
                    y: bd.waterY - (index === 0 ? 46 : 40)
                    width: 4.4; height: 9
                    radius: 2.2
                    color: Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.55)
                }
            }

            // slow rings drifting across the water while the song swims
            Repeater {
                model: 2
                Canvas {
                    id: drift
                    required property int index
                    property real t: 0
                    x: bd.width * (index === 0 ? 0.24 : 0.62)
                    y: bd.waterY - 10
                    width: 84; height: 26
                    onTChanged: requestPaint()
                    SequentialAnimation on t {
                        running: chrome.playing && chrome.awake
                        loops: Animation.Infinite
                        PauseAnimation { duration: (drift.index * 2731) % 3800 }
                        NumberAnimation { from: 0; to: 1; duration: 4800 + drift.index * 1500 }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const tt = t
                        if (tt <= 0 || tt >= 1) return
                        const r = (width / 2) * (0.1 + 0.9 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height * 0.75)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.20 * (1 - tt)))
                        ctx.lineWidth = 1.2
                        ctx.stroke()
                    }
                }
            }

            // ── the fish: every track change, one clean jump ────────────────
            Item {
                id: fish
                property real t: -1
                visible: t >= 0
                readonly property real x0: bd.width * 0.36
                readonly property real span: bd.width * 0.2
                x: x0 + span * Math.max(0, t)
                y: bd.waterY - 34 * Math.sin(Math.PI * Math.max(0, t))
                rotation: -Math.cos(Math.PI * Math.max(0, t)) * 40
                // the fish: a sunlit sliver with a tail nick
                Rectangle { x: -7; y: -2.5; width: 14; height: 5; radius: 2.5; color: chrome.sunA(0.9) }
                Rectangle { x: -10; y: -2; width: 5; height: 4; radius: 1; rotation: 24; color: chrome.sunA(0.65) }
                NumberAnimation {
                    id: jumpAnim
                    target: fish; property: "t"
                    from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine
                    onStopped: { fish.t = -1; splash.splash() }
                }
            }
            Canvas {
                id: splash
                property real t: -1
                visible: t >= 0
                x: fish.x0 + fish.span - 42
                y: bd.waterY - 13
                width: 84; height: 26
                onTChanged: requestPaint()
                function splash() { splashAnim.restart() }
                NumberAnimation {
                    id: splashAnim
                    target: splash; property: "t"
                    from: 0; to: 1; duration: 1700; easing.type: Easing.OutSine
                    onStopped: splash.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 3; k++) {
                        const tt = (t - k * 0.17) / (1 - k * 0.17)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.1 + 0.9 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.4 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 2 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.awake) jumpAnim.restart() }
            }
        }
    }
}
