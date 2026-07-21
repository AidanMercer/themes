import QtQuick
import "chalk.js" as Chalk

// homeroom: class-photo day chrome for the Super+Tab exposé. The room's
// windows become photos taped to the chalkboard: every tile sits on a white
// photo mat with a tape tab, the board behind is slate scattered with chalk
// doodles (the wallpaper's bird, hearts, stars) and the window count
// chalked top-left. Point at a photo and a chalk circle sketches itself
// around it; the photo you came from wears the halo. Visual-only by
// contract: no input handlers; every loop gates on overview.open.
Item {
    id: chrome

    required property var pal        // neon=halo, cyan=periwinkle, magenta=pink…
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    function px(v) { return Math.round(v * pal.uiScale) }
    function chalkA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function sunA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }

    // ── scalars: photos on slate ──
    // deliberate constant: the chalkboard slate a step deeper than pal.glass,
    // so the white photo mats pop against the board
    readonly property color scrimColor: "#141d33"
    readonly property real scrimOpacity: 0.72
    readonly property bool shadowOn: false                  // the mat carries its own
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    readonly property color cardBorder: chalkA(0.25)
    readonly property color cardBorderHot: chalkA(0.85)
    readonly property color cardBorderCenter: Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, 0.8)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 2
    readonly property int cardRadius: 3
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#101828"   // deliberate: darkroom slate behind the photo prints
    readonly property int thumbRadius: 2
    readonly property color titleColor: chalkA(0.6)
    readonly property color titleHotColor: pal.text
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: chalkA(0.55)
    readonly property string hintText: "⏎ focus · esc close"
    readonly property string emptyText: "no windows"

    // ── backdrop: the board, doodled ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // chalk doodles, drawn once — deterministic, same board every time
            Canvas {
                id: doodles
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const c = String(chrome.chalkA(1))
                    const u = chrome.px(1)
                    function heart(x, y, s, seed) {
                        Chalk.strokePath(ctx, [[x, y + s * 0.3], [x - s * 0.5, y - s * 0.2], [x - s * 0.15, y - s * 0.55],
                                               [x, y - s * 0.25], [x + s * 0.15, y - s * 0.55], [x + s * 0.5, y - s * 0.2],
                                               [x, y + s * 0.3], [x, y + s * 0.9]].map(p => [p[0], p[1]]),
                                         { seed: seed, color: c, alpha: 0.20, width: 1.6 * u, ghost: false, dust: 0 })
                    }
                    function star(x, y, s, seed) {
                        Chalk.strokePath(ctx, [[x, y - s], [x + s * 0.3, y - s * 0.25], [x + s, y - s * 0.25],
                                               [x + s * 0.45, y + s * 0.2], [x + s * 0.65, y + s], [x, y + s * 0.5],
                                               [x - s * 0.65, y + s], [x - s * 0.45, y + s * 0.2], [x - s, y - s * 0.25],
                                               [x - s * 0.3, y - s * 0.25], [x, y - s]],
                                         { seed: seed, color: c, alpha: 0.18, width: 1.4 * u, ghost: false, dust: 0 })
                    }
                    // the puffy bird from the wallpaper, bottom-left
                    const bx = width * 0.06, by = height * 0.84, bs = chrome.px(30)
                    Chalk.strokePath(ctx, [[bx, by], [bx + bs * 0.4, by - bs * 0.5], [bx + bs, by - bs * 0.55],
                                           [bx + bs * 1.45, by - bs * 0.2], [bx + bs * 1.3, by + bs * 0.4],
                                           [bx + bs * 0.6, by + bs * 0.5], [bx, by]],
                                     { seed: 43, color: c, alpha: 0.22, width: 1.8 * u, ghost: false, dust: 0 })
                    // its eye and beak
                    Chalk.strokePath(ctx, [[bx + bs * 0.95, by - bs * 0.22], [bx + bs * 0.99, by - bs * 0.16]],
                                     { seed: 47, color: c, alpha: 0.3, width: 2 * u, ghost: false, dust: 0 })
                    Chalk.strokePath(ctx, [[bx + bs * 1.42, by - bs * 0.1], [bx + bs * 1.62, by - bs * 0.02], [bx + bs * 1.42, by + bs * 0.08]],
                                     { seed: 53, color: c, alpha: 0.25, width: 1.5 * u, ghost: false, dust: 0 })
                    heart(width * 0.92, height * 0.16, chrome.px(16), 61)
                    heart(width * 0.13, height * 0.22, chrome.px(11), 67)
                    star(width * 0.87, height * 0.80, chrome.px(14), 71)
                    star(width * 0.08, height * 0.52, chrome.px(9), 73)
                    // bunting across the very top
                    const flags = Math.max(6, Math.floor(width / chrome.px(90)))
                    for (let i = 0; i < flags; i++) {
                        const fx = (i + 0.5) * width / flags
                        Chalk.strokePath(ctx, [[fx - chrome.px(9), chrome.px(14)], [fx + chrome.px(9), chrome.px(14)],
                                               [fx, chrome.px(30)], [fx - chrome.px(9), chrome.px(14)]],
                                         { seed: 83 + i, color: c, alpha: 0.16, width: 1.3 * u, ghost: false, dust: 0 })
                    }
                }
                Component.onCompleted: requestPaint()
            }

            // the window count, chalked top-left
            Text {
                x: chrome.px(30); y: chrome.px(26)
                text: "windows · " + String(chrome.overview.windows.length).padStart(2, "0")
                font.family: chrome.mono
                font.pixelSize: chrome.px(11)
                font.letterSpacing: 3
                color: chrome.chalkA(0.65)
            }
        }
    }

    // ── per-tile: the photo mat, its shadow, and the tape ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: mat
            property var tile: null
            // soft paper shadow, offset down-right
            Rectangle {
                x: -chrome.px(2); y: chrome.px(0)
                width: parent.width + chrome.px(10)
                height: parent.height + chrome.px(16)
                radius: chrome.px(2)
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            // the white photo mat — a little deeper at the foot, like a print
            Rectangle {
                x: -chrome.px(5); y: -chrome.px(5)
                width: parent.width + chrome.px(10)
                height: parent.height + chrome.px(16)
                radius: chrome.px(2)
                color: Qt.rgba(0.96, 0.96, 0.99, 0.92)
            }
            // the tape holding it to the board
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -chrome.px(12)
                width: chrome.px(34); height: chrome.px(10)
                rotation: (mat.tile && mat.tile.index % 2 === 0) ? -5 : 4
                color: chrome.chalkA(0.45)
            }
        }
    }

    // ── per-tile: the chalk circle on the hot photo, the halo on yours ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the chalk circle, sketched around the photo you're pointing at
            Canvas {
                id: ring
                anchors.fill: parent
                anchors.margins: -chrome.px(14)
                property real sweep: 0
                visible: ov.hot && sweep > 0.02
                onSweepChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0 || sweep <= 0) return
                    // an ellipse walked by hand: polyline around the border
                    const n = 26
                    const pts = []
                    const steps = Math.max(2, Math.round(n * sweep))
                    for (let i = 0; i <= steps; i++) {
                        const a = -Math.PI * 0.62 + (i / n) * Math.PI * 2.08
                        pts.push([width / 2 + Math.cos(a) * (width / 2 - chrome.px(5)),
                                  height / 2 + Math.sin(a) * (height / 2 - chrome.px(5))])
                    }
                    Chalk.strokePath(ctx, pts, {
                        seed: 977 + (ov.tile ? ov.tile.index : 0) * 7,
                        color: String(chrome.chalkA(1)), alpha: 0.75,
                        width: chrome.px(2.4), dust: 0.06
                    })
                }
                NumberAnimation { id: sketchIn; target: ring; property: "sweep"; from: 0; to: 1; duration: 260; easing.type: Easing.OutQuad }
            }
            onHotChanged: if (hot) sketchIn.restart(); else ring.sweep = 0

            // the halo, floating over the photo you came from
            Rectangle {
                visible: ov.ctr
                anchors.horizontalCenter: parent.horizontalCenter
                y: -chrome.px(26)
                width: chrome.px(26); height: chrome.px(10); radius: chrome.px(5)
                color: "transparent"
                border.width: chrome.px(2)
                border.color: chrome.pal.neon
                opacity: 0.95
                SequentialAnimation on opacity {
                    running: ov.ctr && chrome.overview.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.55; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.95; duration: 2200; easing.type: Easing.InOutSine }
                }
            }

            // tile number, penciled at the photo's foot
            Text {
                anchors.right: parent.right
                anchors.rightMargin: chrome.px(4)
                anchors.top: parent.bottom
                anchors.topMargin: chrome.px(1)
                text: "no. " + String((ov.tile ? ov.tile.index : 0) + 1).padStart(2, "0")
                font.family: chrome.mono
                font.pixelSize: chrome.px(10)
                color: Qt.rgba(chrome.pal.glass.r, chrome.pal.glass.g, chrome.pal.glass.b, 0.75)
            }
        }
    }
}
