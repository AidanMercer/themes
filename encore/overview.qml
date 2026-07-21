import QtQuick

// encore: the Super+Tab exposé is a monitor wall at the side of the stage —
// every window a screen in the dark, and the stage rig above doing what rigs
// do: the selected screen gets the follow spot (a real light cone drawn from
// the batten down to the tile's place on the ring), the focused one wears an
// active tag, and a row of resting glowsticks leans along the foot of the
// hall. Selection moves as a lighting cue — the cone CUTS to the next
// screen (law 2), it doesn't glide. Visual-only by contract: no input
// handlers; every loop gates on overview.open.
Item {
    id: chrome

    required property var pal        // neon=diva teal, magenta=crowd, amber=follow-spot
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    function px(v) { return Math.round(v * pal.uiScale) }

    // ── scalars: dark screens in a dark hall, capsule corners ──
    // #05070e / #04060c are the wallpaper's hall dark (config.toml bg),
    // deliberately fixed — the scrim must stay stage-black under any retint
    readonly property color scrimColor: "#05070e"
    readonly property real scrimOpacity: 0.72
    readonly property bool shadowOn: false                  // the light pool below replaces it
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    readonly property color cardBorder: Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, 0.9)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, 0.8)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 2
    readonly property int cardRadius: 12
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#04060c"
    readonly property int thumbRadius: 8
    readonly property color titleColor: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.65)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, 0.7)
    readonly property string hintText: "⏎ focus · esc close"
    readonly property string emptyText: "no windows"

    // ── backdrop: the follow spot + the resting glowstick row ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // the follow spot: a cone from the batten straight down onto the
            // selected tile's place on the ring. repaints on selection — a
            // hard cut of light to the next screen, never a sweep.
            Canvas {
                id: spotCone
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onSelectedChanged() { spotCone.requestPaint() }
                    function onTilesChanged() { spotCone.requestPaint() }
                    function onRevealChanged() { spotCone.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const sel = chrome.overview.selected
                    const tiles = chrome.overview.tiles
                    if (sel < 0 || !tiles || sel >= tiles.length) return
                    const t = tiles[sel]
                    const cx = width / 2 + t.rx
                    const cy = height / 2 + t.ry
                    const topX = width / 2 + t.rx * 0.25
                    const spread = Math.max(t.w, 160) * 0.62
                    const col = chrome.pal.amber
                    const g = ctx.createLinearGradient(0, 0, 0, cy)
                    g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.10))
                    g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.03))
                    ctx.fillStyle = g
                    ctx.beginPath()
                    ctx.moveTo(topX - 14, -4)
                    ctx.lineTo(topX + 14, -4)
                    ctx.lineTo(cx + spread, cy)
                    ctx.lineTo(cx - spread, cy)
                    ctx.closePath()
                    ctx.fill()
                    // the pool where the light lands
                    const pool = ctx.createRadialGradient(cx, cy, 0, cx, cy, spread)
                    pool.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.08))
                    pool.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0))
                    ctx.fillStyle = pool
                    ctx.beginPath()
                    ctx.ellipse(cx - spread, cy - spread * 0.35, spread * 2, spread * 0.7)
                    ctx.fill()
                }
            }

            // resting glowsticks along the foot of the hall — the crowd
            // waiting through the song change. printed, deterministic, still.
            Repeater {
                model: 26
                delegate: Rectangle {
                    required property int index
                    readonly property real fx: (index + 0.5) / 26
                    readonly property bool magenta: ((index * 7) % 19) < 4
                    readonly property real tilt: (((index * 37) % 23) / 23 - 0.5) * 38
                    x: Math.round(bd.width * fx)
                    y: bd.height - chrome.px(30) - ((index * 13) % 3) * chrome.px(7)
                    width: chrome.px(3)
                    height: chrome.px(20 + ((index * 11) % 3) * 5)
                    radius: width / 2
                    rotation: tilt
                    color: magenta
                        ? Qt.rgba(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 0.30)
                        : Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.30)
                }
            }

            // the window count, top-left, in the desk's letterspaced dialect
            Text {
                x: chrome.px(28); y: chrome.px(26)
                text: chrome.overview.windows.length + " windows"
                font.family: chrome.mono
                font.pixelSize: chrome.px(10)
                font.letterSpacing: 3
                color: chrome.pal.neon
            }
        }
    }

    // ── per-tile: a dim pool of light under every screen ──
    readonly property Component tileUnderlay: Component {
        Item {
            property var tile: null
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - chrome.px(4)
                width: parent.width * 1.1
                height: chrome.px(14)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.55)
            }
        }
    }

    // ── per-tile: the cue lamp + active tag ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the selected screen's cue lamp, hard-blinking on the count
            Rectangle {
                id: cue
                visible: ov.hot
                anchors.horizontalCenter: parent.horizontalCenter
                y: -chrome.px(14)
                width: chrome.px(8); height: chrome.px(8); radius: width / 2
                color: chrome.pal.amber
                property bool tick: true
                opacity: tick ? 1 : 0.2
                Timer {
                    interval: 500; repeat: true
                    running: ov.hot && chrome.overview.open
                    onTriggered: cue.tick = !cue.tick
                }
                onVisibleChanged: if (!visible) tick = true
            }

            // the focused window's tag
            Rectangle {
                visible: ov.ctr
                x: chrome.px(8)
                y: -chrome.px(10)
                width: activeTag.implicitWidth + chrome.px(12)
                height: chrome.px(18)
                radius: height / 2
                color: "#04060c"
                border.color: chrome.pal.magenta
                border.width: 1
                Text {
                    id: activeTag
                    anchors.centerIn: parent
                    text: "active"
                    font.family: chrome.mono
                    font.pixelSize: chrome.px(10)
                    font.bold: true
                    font.letterSpacing: 2
                    color: chrome.pal.magenta
                }
            }

            // tile number, bottom-right — its place on the ring
            Text {
                anchors.right: parent.right
                anchors.rightMargin: chrome.px(7)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: chrome.px(4)
                text: String((ov.tile ? ov.tile.index : 0) + 1)
                font.family: chrome.mono
                font.pixelSize: chrome.px(10)
                color: ov.hot ? chrome.pal.neon : Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.9)
            }
        }
    }
}
