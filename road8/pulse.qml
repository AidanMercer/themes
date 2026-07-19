import QtQuick

// road8: under the hood. The monitor is the engine bay of the parked car —
// the same 8-bit city burns along the bottom of the window, but here it IS
// the machine: as host.load climbs the grid takes the strain and more amber
// windows burn, in hard eighths, whole windows at a time. A dash strip idles
// top-left — hazard pixel ticking faster as the revs rise, REV and FUEL
// meters in hard 12-block bars, a pixel-font percent that rerolls — and on
// every re-sort a car passes on the hill road. Killing a process stalls the
// engine: the whole display judders in 8px jolts and the city browns out,
// then relights row by row. Everything snaps; nothing glides.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real fuel: host && host.memLoad !== undefined ? host.memLoad : 0

    // the fiction's physics: state moves in whole units — the city takes load
    // in eighths, the meters in twelfths, the readout in whole percent
    readonly property int loadStep: Math.round(load * 8)
    readonly property int revBlocks: Math.round(load * 12)
    readonly property int fuelBlocks: Math.round(fuel * 12)
    readonly property int revPct: Math.round(load * 100)

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color sodium: pal.amber
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount (fifth seed: the
    // engine bay looks out on its own street)
    function rnd(n) {
        let x = Math.imul((n + 331) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // the house pixel font (digits only), for the rev readout
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
        onFaceChanged: requestPaint()
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

    readonly property string wordmark: "▚ UNDER THE HOOD"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8          // the pixel grid
            readonly property int band: 64      // skyline height
            property bool danger: false         // a kill is going through

            // everything rides in the cab so the stall can judder the whole
            // display in hard 8px jolts (no anchors — the x must move)
            Item {
                id: cab
                width: bd.width
                height: bd.height

                // CRT glass behind everything — scanlines + the city glow
                // breathing at the bottom edge; the clock only runs while
                // you're looking
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

                // ── the city as load meter: block wall + towers, and the lit
                // fraction of windows rides chrome.loadStep — a hot CPU wakes
                // the grid a whole eighth at a time ──
                Canvas {
                    id: city
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: bd.band
                    property int step: chrome.loadStep
                    onStepChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const g = bd.g, W = width, H = height
                        const cols = Math.ceil(W / g), rows = H / g
                        const lit = 0.10 + step * 0.02   // idle city → pinned city
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                        ctx.fillRect(0, H - 2 * g, W, 2 * g)
                        let c = 0
                        while (c < cols) {
                            const bw = 2 + Math.floor(chrome.rnd(c * 7 + 1) * 5)
                            const bh = 2 + Math.floor(chrome.rnd(c * 13 + 5) * (rows - 2))
                            ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                            ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                            for (let r = 0; r < bh; r++)
                                for (let k = 0; k < bw; k++) {
                                    const s = chrome.rnd(c * 977 + r * 53 + k * 17)
                                    if (s < lit) {
                                        ctx.fillStyle = s < 0.03 ? String(chrome.starA(0.45))
                                                                 : String(chrome.amberA(0.5))
                                        ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                    }
                                }
                            c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)
                        }
                    }
                }

                // a few ground-floor windows flicker while you watch the
                // gauges — hard on/off, each on its own hashed rhythm
                Repeater {
                    model: 7
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

                // ── the brownout: a kill cuts the city's power, then the grid
                // comes back row by row in whole 8px courses ──
                Rectangle {
                    id: cover
                    property real t: 1   // 0 = blacked out, 1 = all relit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: bd.band - Math.round(t * (bd.band / bd.g)) * bd.g
                    visible: height > 0
                    color: Qt.alpha(chrome.pal.glass, 0.92)
                }

                // the lone star, up and right, breathing slow — the sky is
                // allowed to ease; the displays are not
                Item {
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

                // the hill road in front of the city — a faint guardrail dash
                Row {
                    y: bd.height - bd.band - 8
                    spacing: 12
                    Repeater {
                        model: Math.ceil(bd.width / 24)
                        Rectangle { width: 12; height: 2; color: chrome.amberA(0.12) }
                    }
                }

                // ── the dash strip, top-left: the engine idling in miniature ──
                Row {
                    x: 14
                    y: 10
                    spacing: 8
                    opacity: 0.7

                    // hazard pixel — ticks faster as the revs rise; a kill
                    // turns it taillight red and hammering
                    Rectangle {
                        id: hazard
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4
                        color: bd.danger ? chrome.tail : chrome.sodium
                        property bool tick: true
                        opacity: tick ? 0.9 : 0.18
                        Timer {
                            interval: bd.danger ? 150 : Math.max(500, 1400 - chrome.loadStep * 110)
                            repeat: true
                            running: chrome.awake && bd.visible
                            onTriggered: hazard.tick = !hazard.tick
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REV"
                        color: Qt.alpha(chrome.pal.text, 0.5)
                        font.family: chrome.pal.fontMono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                    }
                    // the rev meter: 12 hard blocks, the top two in the redline
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: 12
                            Rectangle {
                                required property int index
                                readonly property bool lit: index < chrome.revBlocks
                                width: 5; height: 8
                                color: lit ? (index >= 10 ? chrome.tail : chrome.amber) : "transparent"
                                border.width: 1
                                border.color: lit ? "transparent" : Qt.alpha(chrome.pal.dim, 0.6)
                            }
                        }
                    }
                    // the readout, in the house pixel font — rerolls per percent
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: 3
                            PixelGlyph {
                                required property int index
                                ch: String(chrome.revPct).padStart(3, " ").charAt(index)
                                cell: 2
                                face: bd.danger ? chrome.tail : chrome.amber
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FUEL"
                        color: Qt.alpha(chrome.pal.text, 0.5)
                        font.family: chrome.pal.fontMono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                    }
                    // the fuel meter: memory as what's left in the tank
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: 12
                            Rectangle {
                                required property int index
                                readonly property bool lit: index < chrome.fuelBlocks
                                width: 5; height: 8
                                color: lit ? chrome.sodium : "transparent"
                                border.width: 1
                                border.color: lit ? "transparent" : Qt.alpha(chrome.pal.dim, 0.6)
                            }
                        }
                    }
                }

                // ── a car passes on every re-sort: taillights + one exhaust
                // ember, x snapped to the 8px grid, then gone ──
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
            }

            // ── the stall: a kill judders the whole display in hard 8px jolts
            // (no easing — a display takes a hit, it doesn't sway), cuts the
            // city's power, then the grid relights course by course ──
            SequentialAnimation {
                id: stall
                ScriptAction { script: { bd.danger = true; cover.t = 0 } }
                PropertyAction { target: cab; property: "x"; value: -8 }
                PauseAnimation { duration: 50 }
                PropertyAction { target: cab; property: "x"; value: 8 }
                PauseAnimation { duration: 50 }
                PropertyAction { target: cab; property: "x"; value: 0 }
                NumberAnimation { target: cover; property: "t"; from: 0; to: 1; duration: 900 }
                ScriptAction { script: bd.danger = false }
            }

            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onSortIdChanged() { if (chrome.awake) streakAnim.restart() }
                function onKillPulseChanged() { if (chrome.awake) stall.restart() }
            }
        }
    }
}
