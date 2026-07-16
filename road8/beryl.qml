import QtQuick

// road8: night traffic. The browser is the road out of town — the tab strip
// rides on the lane's dashed center line, every navigation is another car
// passing (two taillight pixels dashing the seam under the tabs, snapped to
// the 8px grid), and down behind the status bar the city keeps burning in a
// small bank of amber windows, clear of the url text. CRT glass over it all,
// gated on focus. The wordmark signs off: leaving town. Chrome + voice only;
// beryl's layout stays its own, and everything holds still when you look away.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // beryl window — active (focus), fs, navId

    readonly property bool awake: host ? host.active === true : false

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount (fourth seed: the
    // on-ramp is its own street)
    function rnd(n) {
        let x = Math.imul((n + 811) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: pixel hardware — a thin amber lip, corners barely rounded
    readonly property color cardBorder: Qt.alpha(amber, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property string wordmark: "▸ LEAVING TOWN"

    // the seam between the tab strip and the page: pad 12 + tabs 28 + a hair
    readonly property int seamY: 42

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8

            // CRT glass — scanlines + the city glow breathing at the bottom
            // edge; the clock only runs while the window is looked at
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
                    running: chrome.awake
                }
            }

            // the center line under the tab strip — the tabs drive on it
            Row {
                y: chrome.seamY
                x: 14
                spacing: 12
                Repeater {
                    model: Math.ceil(bd.width / 26)
                    Rectangle { width: 14; height: 2; color: chrome.amberA(0.16) }
                }
            }

            // a small bank of city, bottom-right, behind the wordmark corner —
            // kept off the left half so the url stays crisp
            Canvas {
                id: city
                width: Math.min(220, bd.width * 0.3)
                height: 32
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 6
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
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.5))
                        ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                        for (let r = 0; r < bh; r++)
                            for (let k = 0; k < bw; k++)
                                if (chrome.rnd(c * 977 + r * 53 + k * 17) < 0.2) {
                                    ctx.fillStyle = String(chrome.amberA(0.35))
                                    ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                }
                        c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)
                    }
                }
            }

            // the lone star in the tab-strip sky, far right, breathing slow
            Item {
                x: bd.width - 30
                y: 10
                opacity: 0.6
                Rectangle { x: -1; y: 3; width: 10; height: 2; color: chrome.starA(0.7) }
                Rectangle { x: 3; y: -1; width: 2; height: 10; color: chrome.starA(0.7) }
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.22; duration: 2800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.6; duration: 2800; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── every navigation, another car takes the seam ────────────────────────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Item {
                id: streak
                property real t: -1
                visible: t >= 0
                y: chrome.seamY - 3
                x: Math.round((ov.width + 40) * Math.max(0, t) / 8) * 8 - 20
                Rectangle { x: 0; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: 8; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: -7; y: 1; width: 4; height: 4; color: chrome.amberA(0.35) }
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
