import QtQuick
import "windows.js" as W

// nightshift: chrome for the Super+Tab exposé. The ring of windows reads as the
// district seen from above: the focused window is the block you're standing on,
// every other window is a lit building out across the grid, and thin streets
// run from the centre out to each one. The selected building gets the sodium —
// one warm room at a time, same as everywhere else in this theme.
//
// The shell owns layout, thumbnails, nav and focus. Visual only, no input.
Item {
    id: chrome

    // injected by the exposé (setSource initial properties)
    required property var pal
    required property var overview

    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function inkA(a)    { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // ── the scrim: the city dropped into deep night ─────────────────────────
    readonly property color scrimColor: Qt.rgba(0.008, 0.028, 0.058, 1)
    // lighter than it was, but the exposé still has to win against a screen
    // full of terminals — below ~0.7 the desktop reads as loudly as the tiles
    readonly property real scrimOpacity: 0.72

    // ── tiles as buildings ──────────────────────────────────────────────────
    // the tile chassis is glass; only the thumb backing stays near-solid, since
    // a translucent window's thumbnail has to land on something
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.55)
    readonly property color cardBorder: slateA(0.85)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: hazeA(0.85)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 2
    readonly property color cardHighlight: "transparent"   // the streets do the edging
    readonly property color thumbBg: Qt.rgba(0.01, 0.035, 0.07, 0.86)
    readonly property int thumbRadius: 1
    readonly property bool shadowOn: false
    readonly property color titleColor: inkA(0.80)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: sans
    readonly property string hintText: "arrows move · enter focuses"
    readonly property string emptyText: "nothing open"
    readonly property color hintColor: inkA(0.55)
    readonly property string hintFont: sans

    // ── backdrop: the street grid out to every building ─────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: streets
                anchors.fill: parent
                opacity: chrome.overview.reveal
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const cx = width / 2, cy = height / 2
                    const tiles = chrome.overview.tiles || []
                    const rev = chrome.overview.reveal

                    ctx.lineWidth = 1
                    for (let i = 0; i < tiles.length; i++) {
                        const t = tiles[i]
                        const x = cx + (t.rx || 0) * rev
                        const y = cy + (t.ry || 0) * rev
                        ctx.strokeStyle = String(chrome.slateA(
                            i === chrome.overview.selected ? 0.95 : 0.45))
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(x, y)
                        ctx.stroke()
                        // a kerb mark where the street meets the building
                        ctx.fillStyle = String(i === chrome.overview.selected
                            ? chrome.sodiumA(0.9) : chrome.hazeA(0.4))
                        ctx.fillRect(x - 2, y - 2, 4, 4)
                    }
                    // the block you're standing on
                    ctx.fillStyle = String(chrome.hazeA(0.7))
                    ctx.fillRect(cx - 3, cy - 3, 6, 6)
                }
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { streets.requestPaint() }
                    function onSelectedChanged() { streets.requestPaint() }
                    function onTilesChanged() { streets.requestPaint() }
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── per-tile: a small facade under each building ────────────────────────
    readonly property Component tileUnderlay: Component {
        Item {
            id: tu
            property var tile: null             // injected after load

            Facade {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 5
                cols: 6
                rows: 2
                cell: 4
                gap: 3
                lit: tu.tile && tu.tile.hot ? chrome.pal.neon : chrome.pal.cyan
                dark: chrome.pal.dim
                darkAlpha: 0.30
                dim: tu.tile && tu.tile.hot ? 1.0 : 0.45
                flicker: false
                instant: true
                spread: 240
                plan: {
                    const p = W.blank(6, 2)
                    if (!tu.tile) return p
                    // the centre block burns; the rest keep a couple of rooms on
                    if (tu.tile.isCenter) { for (let i = 0; i < p.length; i++) p[i] = 1 }
                    else {
                        const seed = (tu.tile.index || 0) + 1
                        for (let i = 0; i < p.length; i++)
                            if (((i * 31 + seed * 977) % 100) / 100 < 0.35) p[i] = 1
                    }
                    return p
                }
            }
        }
    }

    // ── per-tile overlay: the sodium sill on the selected building ──────────
    readonly property Component tileOverlay: Component {
        Item {
            id: to
            property var tile: null

            Rectangle {
                visible: to.tile && to.tile.hot === true
                width: parent.width
                height: 2
                y: -2
                color: chrome.pal.neon
            }
            // corner ticks, so the selection reads even against a bright thumb
            Repeater {
                model: to.tile && to.tile.hot === true ? 4 : 0
                Rectangle {
                    required property int index
                    width: 7; height: 1
                    color: chrome.pal.neon
                    x: index % 2 === 0 ? -3 : parent.width - 4
                    y: index < 2 ? -3 : parent.height + 2
                }
            }
        }
    }
}
