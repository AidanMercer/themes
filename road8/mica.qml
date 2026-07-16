import QtQuick

// road8: the glovebox. Below the miller columns the city keeps burning — an
// 8-bit skyline banked along the bottom of the window, dark towers on a
// continuous block wall, a thousand amber windows. The city idles while you
// rummage (a few windows flicker on and off, the lone star breathes, the
// hazard pixel ticks) and holds still the moment you look away. Every
// directory change a car passes: two taillight pixels dash the hill road
// above the rooftops and are gone. Everything moves in 8px steps — it's a
// display, not a photograph.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color sodium: pal.amber
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount; a reload must never
    // reshuffle the skyline under the user
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // the house pixel font (digits only), for the trip odometer
    readonly property var pixmap: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        " ": ["00000","00000","00000","00000","00000","00000","00000"]
    })
    component PixelGlyph: Canvas {
        property string ch: "0"
        property real cell: 2
        property color face: chrome.amber
        readonly property var m: chrome.pixmap[ch] || chrome.pixmap[" "]
        width: (m[0].length + 0.4) * cell
        height: (m.length + 0.4) * cell
        onChChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = cell, gap = Math.max(0.5, c * 0.16)
            ctx.fillStyle = String(face)
            for (let r = 0; r < m.length; r++)
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c, r * c, c - gap, c - gap)
        }
    }

    // chassis: near-square corners, a thin band of city light for an edge —
    // pixel hardware, not glass
    readonly property color cardBorder: Qt.alpha(amber, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    readonly property string wordmark: "▞ GLOVEBOX"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8          // the pixel grid
            readonly property int band: 64      // skyline height
            property int trips: 0               // directories visited this mount

            // CRT glass behind everything — scanlines + the city glow breathing
            // at the bottom edge; the clock only runs while you're looking
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("crt.frag.qsb")
                property real time: 0
                property real px: height
                property color glow: chrome.amber
                opacity: 0.6
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // ── the city: block wall + towers + lit windows, one static draw ──
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
                    // continuous ground wall, two rows — the city block face
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                    ctx.fillRect(0, H - 2 * g, W, 2 * g)
                    // towers rising off it, chunked walk across the columns
                    let c = 0
                    while (c < cols) {
                        const bw = 2 + Math.floor(chrome.rnd(c * 7 + 1) * 5)
                        const bh = 2 + Math.floor(chrome.rnd(c * 13 + 5) * (rows - 2))
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                        ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                        // lit windows — amber, with the rare cold blue one
                        for (let r = 0; r < bh; r++)
                            for (let k = 0; k < bw; k++) {
                                const s = chrome.rnd(c * 977 + r * 53 + k * 17)
                                if (s < 0.22) {
                                    ctx.fillStyle = String(chrome.amberA(s < 0.03 ? 0 : 0.5))
                                    if (s < 0.03) ctx.fillStyle = String(chrome.starA(0.45))
                                    ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                }
                            }
                        c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)   // alley
                    }
                }
            }

            // a handful of ground-floor windows that flicker while you're here —
            // hard on/off, no easing, each on its own hashed rhythm
            Repeater {
                model: 9
                Rectangle {
                    id: flick
                    required property int index
                    width: 4; height: 4
                    color: chrome.amberA(0.5)
                    x: Math.floor(chrome.rnd(index * 17 + 3) * (bd.width / bd.g)) * bd.g + 2
                    y: bd.height - (1 + Math.floor(chrome.rnd(index * 29 + 7) * 2)) * bd.g + 2
                    opacity: 0.8
                    SequentialAnimation on opacity {
                        running: chrome.awake && bd.visible
                        loops: Animation.Infinite
                        onStopped: flick.opacity = 0.8
                        PauseAnimation { duration: 900 + chrome.rnd(flick.index * 41) * 2600 }
                        NumberAnimation { to: 0.12; duration: 0 }
                        PauseAnimation { duration: 140 + chrome.rnd(flick.index * 59) * 420 }
                        NumberAnimation { to: 0.8; duration: 0 }
                    }
                }
            }

            // the lone star, up and right, breathing slow — the sky is allowed
            // to ease; the displays are not
            Item {
                id: star
                x: bd.width - 44
                y: 26
                opacity: 0.75
                Rectangle { x: -1; y: 3; width: 10; height: 2; color: chrome.starA(0.8) }
                Rectangle { x: 3; y: -1; width: 2; height: 10; color: chrome.starA(0.8) }
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.75; duration: 2600; easing.type: Easing.InOutSine }
                }
            }

            // hazard pixel on the dash, top-left — ticking while you rummage
            Rectangle {
                id: hazard
                x: 14; y: 12; width: 4; height: 4
                color: chrome.sodium
                property bool tick: true
                opacity: tick ? 0.7 : 0.18
                Timer {
                    interval: 1200; repeat: true
                    running: chrome.awake && bd.visible
                    onTriggered: hazard.tick = !hazard.tick
                }
            }

            // the trip odometer beside it: every directory is another mile
            Row {
                x: 26; y: 9
                spacing: 5
                opacity: 0.7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TRIP"
                    color: Qt.alpha(chrome.pal.text, 0.5)
                    font.family: chrome.pal.fontMono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 3
                        PixelGlyph {
                            required property int index
                            ch: String(bd.trips % 1000).padStart(3, "0").charAt(index)
                            cell: 2
                        }
                    }
                }
            }

            // the hill road in front of the city — a faint guardrail dash line
            Row {
                y: bd.height - bd.band - 8
                spacing: 12
                Repeater {
                    model: Math.ceil(bd.width / 24)
                    Rectangle { width: 12; height: 2; color: chrome.amberA(0.12) }
                }
            }

            // ── a car passes on every directory change: taillights + one
            // exhaust ember, x snapped to the 8px grid, then gone ──
            Item {
                id: streak
                property real t: -1
                visible: t >= 0
                y: bd.height - bd.band - 13
                x: Math.round((bd.width + 40) * Math.max(0, t) / 8) * 8 - 20
                Rectangle { x: 0; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: 8; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: -7; y: 1; width: 4; height: 4; color: chrome.amberA(0.35) }
                NumberAnimation {
                    id: streakAnim
                    target: streak; property: "t"
                    from: 0; to: 1; duration: 800
                    onStopped: streak.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() {
                    bd.trips++                                // the meter always counts
                    if (chrome.awake) streakAnim.restart()    // the car only shows when seen
                }
            }
        }
    }
}
