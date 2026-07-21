import QtQuick

// sakura: the Super+Tab exposé as the canopy opened up. The scrim is dusk
// under the tree; every window tile hangs from a fine cord dropped from the
// top of the screen (drawn in the backdrop to each tile's real rest position),
// the hovered tile's cord carries a blossom that opens as you drift onto it,
// and the focused window wears a small full bloom at its corner. Petal-slow
// pace; everything gates on overview.open. Visual-only: no input handlers.
Item {
    id: chrome

    required property var pal
    required property var overview   // open, closing, reveal, selected, tiles…

    readonly property color cream: pal.text
    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color plum:  pal.glass
    readonly property string sans: "Noto Sans"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function twigA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // ── scalars ─────────────────────────────────────────────────────────────
    readonly property color scrimColor: "#160f14"      // dusk under the tree
    readonly property real scrimOpacity: 0.74
    readonly property color cardBg: Qt.rgba(plum.r, plum.g, plum.b, 0.93)
    readonly property color cardBorder: twigA(0.8)
    readonly property color cardBorderHot: pink
    readonly property color cardBorderCenter: pinkA(0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 14
    readonly property color cardHighlight: pinkA(0.16)
    readonly property color thumbBg: "#120c10"
    readonly property int thumbRadius: 10
    readonly property bool shadowOn: true
    readonly property color shadowColor: "#0a0608"
    readonly property color titleColor: creamA(0.82)
    readonly property color titleHotColor: pink
    readonly property string titleFont: sans
    readonly property string hintFont: sans
    readonly property color hintColor: pinkA(0.6)
    readonly property string hintText: "pick a window · ⏎ focus · esc close"
    readonly property string emptyText: "no windows"

    // ── backdrop: each tile hangs from the canopy on its own cord ───────────
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            Canvas {
                id: cords
                anchors.fill: parent
                // redraw as the fan settles / selection moves
                readonly property real reveal: chrome.overview.reveal
                readonly property int sel: chrome.overview.selected
                onRevealChanged: requestPaint()
                onSelChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const tiles = chrome.overview.tiles || []
                    const cx = width / 2, cy = height / 2
                    for (let i = 0; i < tiles.length; i++) {
                        const t = tiles[i]
                        const tx = cx + t.rx, ty = cy + t.ry - t.h / 2
                        // the cord: a long shallow curve from the canopy down
                        ctx.beginPath()
                        ctx.moveTo(tx, -4)
                        ctx.bezierCurveTo(tx + 6, ty * 0.35, tx - 6, ty * 0.7, tx, ty * chrome.overview.reveal)
                        ctx.strokeStyle = String(chrome.twigA(i === chrome.overview.selected ? 0.95 : 0.45))
                        ctx.lineWidth = i === chrome.overview.selected ? 1.6 : 1
                        ctx.stroke()
                    }
                }
                Connections {
                    target: chrome.pal
                    function onDimChanged() { cords.requestPaint() }
                }
            }

            // window count, top-left
            Text {
                x: 30; y: 26
                text: "❀ " + chrome.overview.windows.length + " windows"
                font.family: chrome.sans
                font.pixelSize: 14
                font.letterSpacing: 1
                color: chrome.pinkA(0.72)
            }
        }
    }

    // ── per-tile: the blossom on the cord ───────────────────────────────────
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // where the cord meets the tile: a bud normally, a blossom when hot
            Canvas {
                id: knot
                anchors.horizontalCenter: parent.horizontalCenter
                y: -9
                width: 18; height: 18
                property real bloom: ov.hot ? 1 : 0.15
                Behavior on bloom { NumberAnimation { duration: 500; easing.type: Easing.OutSine } }
                onBloomChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = 8, bloomV = knot.bloom
                    ctx.translate(width / 2, height / 2)
                    if (bloomV < 0.1) {
                        ctx.beginPath()
                        ctx.arc(0, 0, 2.6, 0, 2 * Math.PI)
                        ctx.fillStyle = String(chrome.pinkA(0.8))
                        ctx.fill()
                        return
                    }
                    const pr = r * (0.4 + 0.6 * bloomV)
                    const w = pr * 0.55 * (0.55 + 0.45 * bloomV)
                    for (let i = 0; i < 5; i++) {
                        ctx.save()
                        ctx.rotate(i * Math.PI * 2 / 5)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
                        ctx.lineTo(0, -pr * 0.85)
                        ctx.lineTo(pr * 0.16, -pr * 0.97)
                        ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = String(chrome.pinkA(0.5 + bloomV * 0.4))
                        ctx.fill()
                        ctx.restore()
                    }
                    ctx.beginPath()
                    ctx.arc(0, 0, 1.6, 0, 2 * Math.PI)
                    ctx.fillStyle = String(chrome.creamA(0.9))
                    ctx.fill()
                }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { knot.requestPaint() }
                }
            }

            // your current window wears a quiet full bloom at its corner
            Text {
                visible: ov.ctr
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 5
                text: "❀"
                font.pixelSize: 12
                color: chrome.pinkA(0.85)
            }
        }
    }
}
