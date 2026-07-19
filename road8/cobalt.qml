import QtQuick

// road8: the carpool. This is the seat you take calls in, so the night stays
// outside the glass — a dim bank of city surfacing through the translucent
// status line, the lone star breathing in the titlebar sky, the CRT glass
// turned low, and that's all. No meters, no hazards, nothing crawling behind
// a face on a call. The one flourish: every rail hop — chat, calendar,
// activity — is a car crossing the status line, two taillight pixels snapped
// to the 8px grid, then gone.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // cobalt window — active (focus), navId, loading

    readonly property bool awake: host ? host.active === true : false

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount (sixth seed: the
    // carpool waits on its own street)
    function rnd(n) {
        let x = Math.imul((n + 577) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    readonly property string wordmark: "▖ CARPOOL"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8

            // CRT glass, turned low for the call — the clock only runs while
            // the window is looked at
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("crt.frag.qsb")
                property real time: 0
                property real px: height
                property color glow: chrome.amber
                opacity: 0.35
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // ── a low, dim bank of city along the bottom edge — it surfaces
            // faintly through the status line and the stripped Teams regions;
            // one static draw, kept quiet ──
            Canvas {
                id: city
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 32
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = bd.g, W = width, H = height
                    const cols = Math.ceil(W / g), rows = H / g
                    let c = 0
                    while (c < cols) {
                        const bw = 1 + Math.floor(chrome.rnd(c * 7 + 1) * 4)
                        const bh = 1 + Math.floor(chrome.rnd(c * 13 + 5) * rows)
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.45))
                        ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                        for (let r = 0; r < bh; r++)
                            for (let k = 0; k < bw; k++)
                                if (chrome.rnd(c * 977 + r * 53 + k * 17) < 0.16) {
                                    ctx.fillStyle = String(chrome.amberA(0.25))
                                    ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                }
                        c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)
                    }
                }
            }

            // two windows down there flicker, rarely — hard on/off, long
            // pauses; the city minds its own business during the call
            Repeater {
                model: 2
                Rectangle {
                    id: flick
                    required property int index
                    width: 4; height: 4
                    color: chrome.amberA(0.25)
                    x: Math.floor(chrome.rnd(index * 17 + 3) * (bd.width / bd.g)) * bd.g + 2
                    y: bd.height - (1 + index) * bd.g + 2
                    opacity: 0.8
                    SequentialAnimation on opacity {
                        running: chrome.awake && bd.visible
                        loops: Animation.Infinite
                        onStopped: flick.opacity = 0.8
                        PauseAnimation { duration: 2600 + chrome.rnd(flick.index * 41) * 5200 }
                        NumberAnimation { to: 0.12; duration: 0 }
                        PauseAnimation { duration: 180 + chrome.rnd(flick.index * 59) * 420 }
                        NumberAnimation { to: 0.8; duration: 0 }
                    }
                }
            }

            // the lone star in the titlebar sky, far right, breathing slow —
            // the sky is allowed to ease; the displays are not
            Item {
                x: bd.width - 34
                y: 10
                opacity: 0.5
                Rectangle { x: -1; y: 3; width: 10; height: 2; color: chrome.starA(0.6) }
                Rectangle { x: 3; y: -1; width: 2; height: 10; color: chrome.starA(0.6) }
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.18; duration: 3200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.5; duration: 3200; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── every rail hop, a car crosses the status line — transient by design;
    // the overlay holds nothing resident over a call ──
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: streak
                property real t: -1
                visible: t >= 0
                y: ov.height - 12
                x: Math.round((ov.width + 40) * Math.max(0, t) / 8) * 8 - 20
                Rectangle { x: 0; width: 4; height: 4; color: chrome.tail }
                Rectangle { x: 7; width: 4; height: 4; color: chrome.tail }
                Rectangle { x: -6; y: 1; width: 3; height: 3; color: chrome.amberA(0.3) }
                NumberAnimation {
                    id: streakAnim
                    target: streak; property: "t"
                    from: 0; to: 1; duration: 700
                    onStopped: streak.t = -1
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
