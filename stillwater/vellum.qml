import QtQuick

// stillwater: reading at the water's edge. The shore sits lower and dimmer
// here than in mica — the text column owns the window; the waterline is just
// what waits under the page. While a page is up in a focused window two
// small lamps breathe on the line; the moment you start typing the water
// holds absolutely still (the reading gate, verbatim). When a page composes,
// the mirror acknowledges it: one slow ripple ring blooms flat on the
// waterline and is gone — stillwater's page-turn, in place of any scan or
// flash. Chrome only; vellum's layout stays its own.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }

    // deterministic hash — the same shore on every mount
    function rnd(n) {
        let x = Math.imul((n + 311) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: soft water glass
    readonly property color cardBorder: Qt.alpha(sky, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real wl: height - 36   // a low, humble shore

            Rectangle {
                x: 0; y: bd.wl
                width: parent.width
                height: parent.height - bd.wl
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle { x: 0; y: bd.wl; width: parent.width; height: 1; color: chrome.skyA(0.16) }

            // a few dim lamps, streaks barely there — one static draw
            Canvas {
                id: shore
                anchors.fill: parent
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const wl = bd.wl, W = width
                    const n = Math.max(4, Math.floor(W / 170))
                    for (let i = 0; i < n; i++) {
                        const fx = 0.06 + chrome.rnd(i * 17 + 3) * 0.88
                        const lv = 0.25 + chrome.rnd(i * 29 + 7) * 0.45
                        const cx = Math.round(W * fx)
                        ctx.fillStyle = String(chrome.lampA(0.18 + 0.35 * lv))
                        ctx.fillRect(cx - 1.5, wl - 3, 3, 3)
                        let y = wl + 4, k = 0
                        while (y < wl + 4 + lv * 14 && y < height - 2) {
                            ctx.fillStyle = String(chrome.lampA(lv * 0.22 * (1 - (y - wl) / 20)))
                            ctx.fillRect(cx - 1, y, 2, 2)
                            y += 4 + k * 2
                            k++
                        }
                    }
                }
            }

            // two lamps breathe while you read; still while you write
            Repeater {
                model: 2
                Rectangle {
                    id: readLamp
                    required property int index
                    x: Math.round(bd.width * (0.28 + index * 0.4)) - 2
                    y: bd.wl - 4
                    width: 4; height: 4
                    radius: 2
                    color: chrome.lamp
                    opacity: 0.4
                    SequentialAnimation on opacity {
                        running: chrome.stirring && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 3000 + readLamp.index * 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.6; duration: 3000 + readLamp.index * 800; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ── the page composes: one ripple on the line, then stillness ──
            Item {
                id: ripple
                x: Math.round(bd.width * 0.5)
                y: bd.wl
                property real t: -1
                visible: t >= 0
                Rectangle {
                    anchors.centerIn: parent
                    width: 6 + 120 * Math.max(0, ripple.t)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: chrome.lampA(0.4 * (1 - Math.max(0, ripple.t)))
                    transform: Scale { origin.y: (6 + 120 * Math.max(0, ripple.t)) / 2; yScale: 0.2 }
                }
                NumberAnimation {
                    id: rippleAnim
                    target: ripple; property: "t"
                    from: 0; to: 1; duration: 1600; easing.type: Easing.OutSine
                    onStopped: ripple.t = -1
                }
            }
            // gate on `page`, NOT `stirring` — alt-tabbing must not re-fire
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) rippleAnim.restart() }
            }
        }
    }
}
