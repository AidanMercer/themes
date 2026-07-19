import QtQuick

// bog: the far bank. The browser looks out across the pond — the seam under
// the tab strip is the waterline (a run of sun-glints instead of a hard
// rule), a small cluster of reeds stands behind the status bar in the
// bottom-right, and on every committed navigation a fish jumps the seam: a
// sunlit arc over the waterline, then rings where it went back under. The
// page owns the middle of the window, so everything here lives in the
// chrome bands. Chrome + voice only; still whenever the window isn't
// looked at.
Item {
    id: chrome

    required property var pal   // snapshot palette (sun/moss/rust…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color sun: pal.neon
    readonly property color moss: pal.cyan
    readonly property color reed: pal.dim
    function sunA(a)  { return Qt.rgba(sun.r, sun.g, sun.b, a) }
    function mossA(a) { return Qt.rgba(moss.r, moss.g, moss.b, a) }
    function reedA(a) { return Qt.rgba(reed.r, reed.g, reed.b, a) }

    // deterministic hash — the same bank on every mount
    function rnd(n) {
        let x = Math.imul((n + 131) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: pebble-smooth glass with a moss lip
    readonly property color cardBorder: Qt.alpha(moss, 0.35)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    readonly property string wordmark: "≈ the far bank"

    // the seam between the tab strip and the page
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the waterline under the tabs: glints, not a rule
            Repeater {
                model: Math.max(4, Math.ceil(bd.width / 90))
                Rectangle {
                    required property int index
                    x: 16 + index * 90 + chrome.rnd(index * 13) * 30
                    y: chrome.seamY
                    width: index % 2 === 0 ? 20 : 10
                    height: 2
                    radius: 1
                    color: chrome.sunA(index % 3 === 0 ? 0.25 : 0.13)
                }
            }

            // the reed cluster behind the status bar, bottom-right
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: bd.width - 58 + index * 10
                    y: bd.height - height - 4
                    width: 1.6
                    height: 16 + chrome.rnd(index * 17 + 3) * 14
                    radius: 1
                    rotation: (chrome.rnd(index * 23) - 0.5) * 12
                    transformOrigin: Item.Bottom
                    color: chrome.reedA(0.7)
                }
            }
            Rectangle {   // one cattail head among them
                x: bd.width - 39
                y: bd.height - 30
                width: 4; height: 8
                radius: 2
                color: Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.5)
            }
        }
    }

    // ── every navigation, a fish jumps the seam ─────────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov

            Item {
                id: fish
                property real t: -1
                visible: t >= 0
                readonly property real x0: ov.width * 0.30
                readonly property real span: ov.width * 0.16
                x: x0 + span * Math.max(0, t)
                y: chrome.seamY - 22 * Math.sin(Math.PI * Math.max(0, t))
                rotation: -Math.cos(Math.PI * Math.max(0, t)) * 38
                Rectangle { x: -6; y: -2; width: 12; height: 4; radius: 2; color: chrome.sunA(0.9) }
                Rectangle { x: -8.5; y: -1.6; width: 4; height: 3.2; radius: 1; rotation: 24; color: chrome.sunA(0.6) }
                NumberAnimation {
                    id: jumpAnim
                    target: fish; property: "t"
                    from: 0; to: 1; duration: 950; easing.type: Easing.InOutSine
                    onStopped: { fish.t = -1; splashAnim.restart() }
                }
            }
            Canvas {
                id: splash
                property real t: -1
                visible: t >= 0
                x: ov.width * 0.46 - 36
                y: chrome.seamY - 10
                width: 72; height: 22
                onTChanged: requestPaint()
                NumberAnimation {
                    id: splashAnim
                    target: splash; property: "t"
                    from: 0; to: 1; duration: 1500; easing.type: Easing.OutSine
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
                        ctx.strokeStyle = String(chrome.sunA(0.38 * (1 - tt)))
                        ctx.lineWidth = Math.max(0.8, 1.8 * (1 - tt))
                        ctx.stroke()
                    }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) jumpAnim.restart() }
            }
        }
    }
}
