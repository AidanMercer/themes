import QtQuick

// bog: the gathering pool — where the pond's residents meet. Deliberately
// the calmest water in the theme (calls happen here): the backdrop keeps a
// faint waterline low in the window with a few glints, surfacing through
// cobalt's stripped Teams regions, and a soft moss vignette settles into
// the bottom corners. Every rail navigation — chat, calendar, activity —
// is one slow ring low on the water, then stillness. No input handlers;
// everything gates on focus.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    readonly property string wordmark: "≈ the gathering pool"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real waterY: height - 40

            // moss settling into the bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: parent.width * 0.3
                height: 90
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.mossA(0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width * 0.3
                height: 90
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.mossA(0.07) }
                }
            }

            // the waterline, quiet
            Rectangle {
                x: 12; y: bd.waterY
                width: parent.width - 24
                height: 1
                color: chrome.reedA(0.35)
            }
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    x: 30 + index * ((bd.width - 72) / 4)
                    y: bd.waterY - 1
                    width: index % 2 === 0 ? 14 : 7
                    height: 2
                    radius: 1
                    color: chrome.sunA(0.12)
                }
            }
        }
    }

    // ── a rail hop: one slow ring, then stillness ───────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            Canvas {
                id: ring
                property real t: -1
                visible: t >= 0
                x: ov.width * 0.5 - 60
                y: ov.height - 56
                width: 120; height: 34
                onTChanged: requestPaint()
                NumberAnimation {
                    id: ringAnim
                    target: ring; property: "t"
                    from: 0; to: 1; duration: 2000; easing.type: Easing.OutSine
                    onStopped: ring.t = -1
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (t < 0) return
                    for (let k = 0; k < 2; k++) {
                        const tt = (t - k * 0.22) / (1 - k * 0.22)
                        if (tt <= 0 || tt >= 1) continue
                        const r = (width / 2) * (0.1 + 0.9 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.28)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.22 * (1 - tt)))
                        ctx.lineWidth = 1.2
                        ctx.stroke()
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) ringAnim.restart() }
            }
        }
    }
}
