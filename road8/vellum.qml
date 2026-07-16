import QtQuick

// road8: reading by dome light. The city sits lower and dimmer here than in
// mica — the text column owns the window; the skyline is just what's past the
// windshield. While a page is up the city idles (two windows flicker, the
// star breathes); the moment you start typing everything parks. When a page
// composes, the display takes new data: one amber scan row steps down the
// window in 8px increments and is gone — road8's reroll, at window scale.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: near-square corners — pixel hardware, not glass
    readonly property color cardBorder: Qt.alpha(amber, 0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8      // the pixel grid
            readonly property int band: 48  // shorter skyline — the page rules here

            // CRT glass behind the panes — scanlines + the city glow breathing
            // at the bottom edge. the clock obeys the reading gate: it only
            // runs while a page is up in a focused window, so a text buffer
            // being typed into never hums
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("crt.frag.qsb")
                property real time: 0
                property real px: height
                property color glow: chrome.amber
                opacity: 0.55
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // the dome light: a warm pool from the cabin ceiling that switches
            // on with the page and off for the road (one state fade, then still)
            Canvas {
                id: dome
                width: 300
                height: 130
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: chrome.page ? 0.4 : 0
                Behavior on opacity { NumberAnimation { duration: 450 } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const a = width / 2
                    ctx.save()
                    ctx.scale(1, height / a)
                    const g = ctx.createRadialGradient(a, 0, 0, a, 0, a)
                    g.addColorStop(0, String(chrome.amberA(0.16)))
                    g.addColorStop(1, String(chrome.amberA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, a)
                    ctx.restore()
                }
                Component.onCompleted: requestPaint()
            }

            // ── the city, dimmed for reading: block wall + towers + windows ──
            Canvas {
                id: city
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = bd.g, W = width, H = height
                    const cols = Math.ceil(W / g), rows = H / g
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.45))
                    ctx.fillRect(0, H - 2 * g, W, 2 * g)
                    let c = 0
                    while (c < cols) {
                        const bw = 2 + Math.floor(chrome.rnd(c * 7 + 1) * 5)
                        const bh = 2 + Math.floor(chrome.rnd(c * 13 + 5) * (rows - 2))
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.45))
                        ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                        for (let r = 0; r < bh; r++)
                            for (let k = 0; k < bw; k++)
                                if (chrome.rnd(c * 977 + r * 53 + k * 17) < 0.18) {
                                    ctx.fillStyle = String(chrome.amberA(0.3))
                                    ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                }
                        c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)
                    }
                }
            }

            // two ground-floor windows flicker while you read — hard on/off
            Repeater {
                model: 2
                Rectangle {
                    id: flick
                    required property int index
                    width: 4; height: 4
                    color: chrome.amberA(0.32)
                    x: Math.floor(chrome.rnd(index * 17 + 3) * (bd.width / bd.g)) * bd.g + 2
                    y: bd.height - (1 + index) * bd.g + 2
                    opacity: 0.8
                    SequentialAnimation on opacity {
                        running: chrome.stirring && bd.visible
                        loops: Animation.Infinite
                        onStopped: flick.opacity = 0.8
                        PauseAnimation { duration: 1400 + chrome.rnd(flick.index * 41) * 3200 }
                        NumberAnimation { to: 0.12; duration: 0 }
                        PauseAnimation { duration: 160 + chrome.rnd(flick.index * 59) * 420 }
                        NumberAnimation { to: 0.8; duration: 0 }
                    }
                }
            }

            // the lone star, top-right, breathing only while a page is up
            Item {
                id: star
                x: bd.width - 40
                y: 22
                opacity: 0.55
                Rectangle { x: -1; y: 3; width: 10; height: 2; color: chrome.starA(0.7) }
                Rectangle { x: 3; y: -1; width: 2; height: 10; color: chrome.starA(0.7) }
                SequentialAnimation on opacity {
                    running: chrome.stirring && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.22; duration: 2800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.55; duration: 2800; easing.type: Easing.InOutSine }
                }
            }

            // ── the page takes data: one scan row steps top-to-bottom on the
            // 8px grid as the page composes, then it's gone ──
            Rectangle {
                id: scan
                property real t: -1
                visible: t >= 0
                width: bd.width
                height: 2
                color: chrome.amberA(0.3)
                y: Math.round((bd.height * Math.max(0, t)) / 8) * 8
                opacity: 1 - Math.max(0, t) * 0.7
                NumberAnimation {
                    id: scanAnim
                    target: scan; property: "t"
                    from: 0; to: 1; duration: 520
                    onStopped: scan.t = -1
                }
            }
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.stirring) scanAnim.restart() }
            }
        }
    }
}
