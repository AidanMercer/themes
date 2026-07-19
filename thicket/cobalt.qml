import QtQuick

// thicket: cobalt is the call blind — the one place the watcher keeps almost
// everything still, because Aidan takes calls here. Under the glass bars and
// the stripped Teams regions: two faint leaf sprays holding opposite corners
// and one soft dapple of canopy light, all static. The only motion this file
// owns is the rail switch — chat, calendar, activity — which sends a single
// quiet rustle line darting under the titlebar, then the blind is still
// again. No input handlers anywhere; restraint is the voice here.
Item {
    id: chrome

    required property var pal   // snapshot palette (ember/iris/ember-red/…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color dapple: pal.amber
    function dappleA(a) { return Qt.rgba(dapple.r, dapple.g, dapple.b, a) }
    function leafA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    function rnd(n) {
        let x = Math.imul((n + 449) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property string wordmark: "thicket"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // two corner sprays, faint — one draw
            Canvas {
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
                        { x: -2, y: h * 0.12, a0: -0.5, n: 5 },
                        { x: w + 2, y: h * 0.92, a0: Math.PI - 0.7, n: 5 }
                    ]
                    let s = 0
                    for (const fan of fans) {
                        for (let i = 0; i < fan.n; i++) {
                            s++
                            const ang = fan.a0 + (i / fan.n) * 1.1 + (chrome.rnd(s * 7) - 0.5) * 0.25
                            const len = 22 + chrome.rnd(s * 13) * 26
                            const wid = 6 + chrome.rnd(s * 17) * 5
                            const r = chrome.rnd(s * 41)
                            const fill = r < 0.3 ? "rgba(23,44,38,0.55)"
                                       : "rgba(6,10,8,0.6)"
                            leafShape(ctx, fan.x, fan.y, len, wid, ang, fill)
                        }
                    }
                }
            }

            // one soft dapple, low-center — static
            Canvas {
                width: 320; height: 180
                x: bd.width * 0.55 - width / 2
                y: bd.height * 0.62 - height / 2
                opacity: 0.8
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = ctx.createRadialGradient(width / 2, height / 2, 6, width / 2, height / 2, width / 2)
                    g.addColorStop(0, String(chrome.dappleA(0.05)))
                    g.addColorStop(1, String(chrome.dappleA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── the rail switch: one quiet rustle line under the titlebar ──────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Rectangle {
                id: streakLine
                property real t: -1
                visible: t >= 0
                y: 44
                height: 1
                x: -60 + (ov.width + 120) * Math.max(0, t) - width
                width: 90
                opacity: t < 0 ? 0 : Math.sin(Math.min(1, t) * Math.PI) * 0.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: chrome.dappleA(0.7) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                NumberAnimation {
                    id: streakAnim
                    target: streakLine; property: "t"
                    from: 0; to: 1; duration: 520
                    easing.type: Easing.OutQuad
                    onStopped: streakLine.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) streakAnim.restart() }
            }
        }
    }
}
