import QtQuick

// bog: wading the shallows. Below the miller columns the pond's edge runs
// across the window — a waterline with sun-glints, smooth pebbles resting
// under the surface, one dragonfly perched on the rim of the water doing
// nothing in particular (it bobs while you rummage and holds still the
// moment you look away). Every directory change is a pebble dropped: rings
// spread from a spot on the waterline and are gone. Chrome + voice only;
// mica's layout stays its own.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    // deterministic hash — the same shallows on every mount
    function rnd(n) {
        let x = Math.imul((n + 37) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: pebble-smooth glass with a moss lip
    readonly property color cardBorder: Qt.alpha(moss, 0.35)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property string wordmark: "≈ the shallows"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real waterY: height - 46
            property int visits: 0

            // the waterline
            Rectangle {
                x: 8; y: bd.waterY
                width: parent.width - 16
                height: 1
                color: chrome.reedA(0.5)
            }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    x: 20 + index * ((bd.width - 52) / 7)
                    y: bd.waterY - 1
                    width: index % 2 === 0 ? 16 : 8
                    height: 2
                    radius: 1
                    color: chrome.sunA(0.20)
                }
            }
            // the shallows below: a faint moss wash and pebbles under water
            Rectangle {
                x: 1; y: bd.waterY + 1
                width: parent.width - 2
                height: parent.height - bd.waterY - 2
                color: chrome.mossA(0.05)
            }
            Repeater {
                model: 11
                Rectangle {
                    required property int index
                    x: 18 + chrome.rnd(index * 19 + 5) * (bd.width - 60)
                    y: bd.waterY + 8 + chrome.rnd(index * 7 + 2) * 24
                    width: 10 + chrome.rnd(index * 11) * 16
                    height: width * (0.45 + chrome.rnd(index * 3) * 0.2)
                    radius: height / 2
                    color: index % 3 === 0 ? chrome.sunA(0.10) : chrome.reedA(0.35)
                }
            }

            // the dragonfly perched at the water's rim, top-right of the line
            Item {
                id: dfly
                x: bd.width - 66
                y: bd.waterY - 14
                property real hover: 0
                transform: Translate { y: dfly.hover }
                SequentialAnimation on hover {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: -3; duration: 2100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.4; duration: 2100; easing.type: Easing.InOutSine }
                }
                opacity: 0.7
                Rectangle { x: 0; y: 5; width: 13; height: 1.6; radius: 0.8; color: chrome.mossA(0.9) }
                Rectangle { x: 12.4; y: 4.2; width: 3; height: 3; radius: 1.5; color: chrome.mossA(1) }
                Rectangle { x: 3; y: 1; width: 5; height: 2.6; radius: 1.3; rotation: -26; color: chrome.sunA(0.4) }
                Rectangle { x: 7.5; y: 1; width: 5; height: 2.6; radius: 1.3; rotation: 22; color: chrome.sunA(0.4) }
            }

            // ── every directory is a pebble dropped somewhere new ───────────
            Canvas {
                id: plop
                property real t: -1
                property real px: bd.width * 0.4
                visible: t >= 0
                x: px - 50
                y: bd.waterY - 14
                width: 100; height: 30
                onTChanged: requestPaint()
                NumberAnimation {
                    id: plopAnim
                    target: plop; property: "t"
                    from: 0; to: 1; duration: 1800; easing.type: Easing.OutSine
                    onStopped: plop.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 3; k++) {
                        const tt = (t - k * 0.16) / (1 - k * 0.16)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.08 + 0.92 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.35 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 1.8 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    bd.visits++
                    if (!chrome.awake) return
                    // each pebble lands somewhere else along the line
                    plop.px = bd.width * (0.15 + chrome.rnd(bd.visits * 71 + 9) * 0.7)
                    plopAnim.restart()
                }
            }
        }
    }
}
