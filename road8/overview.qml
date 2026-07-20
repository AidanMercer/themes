import QtQuick

// road8: 8-bit night chrome for the Super+Tab exposé.
//
// the exposé becomes a sprite-select screen parked above the city: every
// window is a sprite frame with a hard pixel shadow, the acquired frame gets
// the classic blinking ▶ cursor, and a stepped rooftop skyline with lit amber
// windows runs along the bottom — one taillight sliding through it in 3px
// jumps. the rule everywhere: nothing eases. blinks are hard steps, movement
// is frame-flips (Timers + PauseAnimations, zero easing curves), same as the
// popup's CHECK lamp and ▸▸▸ ticker.
//
// visual-only by contract: no input handlers; every loop gates on `up`
// (open OR closing — the shell tears the layers down ~300ms after close, and
// the flips have to keep going for that tail or they snap).
Item {
    id: chrome

    required property var pal        // neon=city amber, cyan=starlight slate,
                                     // magenta=taillight, amber=sodium, dim=asphalt
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    function px(v) { return Math.round(v * pal.uiScale) }   // pixel art hates fractions

    // the flips have to keep running through the close, not just while open —
    // stopping a value-source mid-blink snaps its opacity and reads as a flicker
    readonly property bool up: overview.open || overview.closing

    // ── scalars: pixel-square frames, no gloss, no soft shadow ──
    readonly property color scrimColor: "#05060a"
    readonly property real scrimOpacity: 0.66
    readonly property bool shadowOn: false                  // hard slab drawn below
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    readonly property color cardBorder: pal.dim
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.7)
    readonly property int cardBorderWidth: 2
    readonly property int cardBorderWidthHot: 3
    readonly property int cardBorderWidthCenter: 2
    readonly property int cardRadius: 2                     // no soft corners on this road
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#07080c"
    readonly property int thumbRadius: 0
    readonly property color titleColor: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.8)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.75)
    readonly property string hintText: "SELECT WINDOW · ⏎ START · ESC QUIT"
    readonly property string emptyText: "NO SIGNAL"

    // ── backdrop: pixel stars + stepped skyline + one taillight heading out ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // square stars that twinkle in hard steps — no fades, just frames.
            // deterministic scatter off the index so remounts don't reshuffle.
            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    readonly property real fx: (((index * 73) % 97) / 97)
                    readonly property real fy: (((index * 41) % 53) / 53)
                    x: Math.round(bd.width * (0.04 + fx * 0.92))
                    y: Math.round(bd.height * (0.05 + fy * 0.38))
                    width: chrome.px(index % 3 === 0 ? 3 : 2)
                    height: width
                    color: index % 4 === 0 ? chrome.pal.neon : chrome.pal.cyan
                    SequentialAnimation on opacity {
                        running: chrome.up
                        loops: Animation.Infinite
                        PropertyAction { value: 0.9 }
                        PauseAnimation { duration: 900 + ((index * 137) % 1400) }
                        PropertyAction { value: 0.25 }
                        PauseAnimation { duration: 350 + ((index * 89) % 500) }
                    }
                }
            }

            // stepped rooftop silhouette with lit windows, painted once per
            // size/pal change — positions derive from index math, not random,
            // so repaints are stable frames of the same city.
            Canvas {
                id: skyline
                anchors.bottom: parent.bottom
                width: parent.width
                height: chrome.px(96)
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { skyline.requestPaint() }
                    function onDimChanged() { skyline.requestPaint() }
                    function onAmberChanged() { skyline.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    const u = Math.max(2, chrome.px(3))      // one "pixel"
                    // rooftops: stepped blocks marching across, heights hashed
                    ctx.fillStyle = Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.55)
                    let x = 0, i = 0
                    while (x < w) {
                        const bw = u * (4 + ((i * 31) % 7))          // building width
                        const bh = u * (6 + ((i * 17) % 18))         // building height
                        ctx.fillRect(x, h - bh, bw, bh)
                        // lit windows: 2x1-unit amber cells on a grid, hashed on
                        const cols = Math.max(1, Math.floor(bw / (2 * u)) - 1)
                        const rows = Math.max(1, Math.floor(bh / (2 * u)) - 1)
                        ctx.fillStyle = chrome.pal.neon
                        for (let cx = 0; cx < cols; cx++)
                            for (let cy = 0; cy < rows; cy++)
                                if (((i * 7 + cx * 3 + cy * 5) % 5) === 0)
                                    ctx.fillRect(x + u + cx * 2 * u, h - bh + u + cy * 2 * u,
                                                 u, Math.round(u * 0.7))
                        ctx.fillStyle = Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.55)
                        x += bw + u * (1 + (i % 3))
                        i++
                    }
                    // the road itself: one sodium lamp band above the bottom edge
                    ctx.fillStyle = Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.25)
                    ctx.fillRect(0, h - u, w, Math.round(u / 2))
                }
            }

            // one taillight leaving town — slides right-to-left in hard 3px
            // jumps on a frame timer, wraps, gated on open.
            Rectangle {
                id: car
                width: chrome.px(6)
                height: chrome.px(3)
                color: chrome.pal.magenta
                y: bd.height - chrome.px(7)
                x: bd.width * 0.8
                Timer {
                    interval: 90
                    repeat: true
                    running: chrome.up
                    onTriggered: {
                        car.x -= chrome.px(3)
                        if (car.x < -car.width) car.x = bd.width + car.width
                    }
                }
            }

            // level tag, top-left, in the popup's letterspaced dialect
            Text {
                x: chrome.px(28); y: chrome.px(26)
                text: "WORLD 8-0 · " + String(chrome.overview.windows.length).padStart(2, "0") + " UP"
                font.family: chrome.mono
                font.pixelSize: chrome.px(10)
                font.letterSpacing: 3
                color: chrome.pal.neon
            }
        }
    }

    // ── per-tile: hard pixel slab shadow under every sprite frame ──
    readonly property Component tileUnderlay: Component {
        Item {
            property var tile: null
            // solid slab offset down-right, no blur — sprite pasted on the night
            Rectangle {
                x: chrome.px(4); y: chrome.px(4)
                width: parent.width; height: parent.height
                color: "#04050a"
                opacity: 0.85
            }
        }
    }

    // ── per-tile: blinking ▶ cursor, P1 badge, stepped corner pixels ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // corner pixels: a single square nicked into each corner fakes the
            // chunky sprite-rounding without touching the shell's card
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: chrome.px(3); height: width
                    x: index % 2 === 0 ? -1 : ov.width - width + 1
                    y: index < 2 ? -1 : ov.height - height + 1
                    color: ov.hot ? chrome.pal.neon : chrome.pal.dim
                }
            }

            // the menu cursor: hard-blinking ▶ parked left of the acquired frame
            Text {
                visible: ov.hot
                anchors.right: parent.left
                anchors.rightMargin: chrome.px(8)
                anchors.verticalCenter: parent.verticalCenter
                text: "▶"
                font.family: chrome.mono
                font.pixelSize: chrome.px(14)
                color: chrome.pal.neon
                SequentialAnimation on opacity {
                    running: ov.hot && chrome.up
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 420 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 420 }
                }
            }

            // P1 badge on the frame you're playing
            Rectangle {
                visible: ov.ctr
                x: chrome.px(6)
                y: -chrome.px(9)
                width: p1.implicitWidth + chrome.px(10)
                height: chrome.px(15)
                color: "#07080c"
                border.color: chrome.pal.amber
                border.width: 1
                Text {
                    id: p1
                    anchors.centerIn: parent
                    text: "P1"
                    font.family: chrome.mono
                    font.pixelSize: chrome.px(9)
                    font.bold: true
                    color: chrome.pal.amber
                }
            }

            // frame number, bottom-right, like a sprite sheet index
            Text {
                anchors.right: parent.right
                anchors.rightMargin: chrome.px(6)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: chrome.px(4)
                text: String(ov.tile ? ov.tile.index : 0).padStart(2, "0")
                font.family: chrome.mono
                font.pixelSize: chrome.px(8)
                color: ov.hot ? chrome.pal.neon : Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.9)
            }
        }
    }
}
