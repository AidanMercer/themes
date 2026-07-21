import QtQuick

// thicket: chrome for the Super+Tab exposé — THE CLEARING. Zooming out is
// stepping back into cover: the desktop recedes behind a rim of dark leaves
// that press in from the screen edges, and every window becomes something
// spotted out in the open. The window under consideration is the one being
// WATCHED: the eyeshine pair sits beside it (blinking its slow blink, darting
// tile-to-tile as the selection moves), while the focused window carries a
// small ember berry — the one you already hold. Titles whisper in serif.
//
// visual-only by contract: no input handlers; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=ember, cyan=iris, magenta=ember-red,
                                     // amber=dapple, dim=leaf grey-green
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function px(v) { return Math.round(v * pal.uiScale) }
    function leafA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function emberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function irisA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // ── scalars: foliage glass, soft leaf-dark edges ──
    readonly property color scrimColor: "#050a08"
    readonly property real scrimOpacity: 0.72
    readonly property bool shadowOn: true
    readonly property color shadowColor: "#030605"
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: leafA(0.8)
    readonly property color cardBorderHot: pal.cyan
    readonly property color cardBorderCenter: emberA(0.75)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 10
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#060a08"
    readonly property int thumbRadius: 8
    readonly property color titleColor: leafA(1.0)
    readonly property color titleHotColor: pal.cyan
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: irisA(0.7)
    readonly property string hintText: "enter to focus · esc to close"
    readonly property string emptyText: "nothing open"

    // ── backdrop: the rim of the clearing ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // leaves pressing in from every edge — one draw, rides the zoom
            Canvas {
                id: rim
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height
                    function leafShape(x, y, len, wid, ang, fill) {
                        ctx.save()
                        ctx.translate(x, y); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = fill
                        ctx.fill()
                        ctx.restore()
                    }
                    for (let i = 0; i < 60; i++) {
                        const side = i % 4
                        const f = chrome.rnd(i * 19 + 7)
                        const d = chrome.rnd(i * 23 + 3) * chrome.px(70)
                        const len = chrome.px(30 + chrome.rnd(i * 17 + 9) * 40)
                        const wid = chrome.px(8 + chrome.rnd(i * 29 + 4) * 9)
                        let x, y, ang
                        if (side === 0)      { x = w * f; y = d; ang = Math.PI / 2 + (chrome.rnd(i * 3) - 0.5) * 1.4 - Math.PI }
                        else if (side === 1) { x = w * f; y = h - d; ang = -Math.PI / 2 + (chrome.rnd(i * 3) - 0.5) * 1.4 - Math.PI }
                        else if (side === 2) { x = d; y = h * f; ang = (chrome.rnd(i * 3) - 0.5) * 1.4 - Math.PI }
                        else                 { x = w - d; y = h * f; ang = (chrome.rnd(i * 3) - 0.5) * 1.4 }
                        const r = chrome.rnd(i * 41 + 6)
                        const fill = r < 0.25 ? "rgba(20,38,33,0.9)"
                                   : r < 0.45 ? "rgba(12,17,15,0.92)"
                                   : "rgba(4,7,6,0.94)"
                        leafShape(x, y, len, wid, ang, fill)
                    }
                }
            }

            // a couple of dapple pools lying between the tiles
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real fx: chrome.rnd(index * 53 + 11)
                    readonly property real fy: chrome.rnd(index * 37 + 29)
                    x: bd.width * (0.15 + fx * 0.7) - width / 2
                    y: bd.height * (0.15 + fy * 0.7) - height / 2
                    width: chrome.px(220 + fx * 120)
                    height: width * 0.55
                    radius: height / 2
                    rotation: -20 + fx * 40
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.05) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // window count, top-left
            Text {
                x: chrome.px(30); y: chrome.px(28)
                text: String(chrome.overview.windows.length) + " windows"
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: chrome.px(13)
                color: chrome.irisA(0.7)
            }
        }
    }

    // ── per-tile: the watcher's attention ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the eyeshine beside the watched tile — appears with a blink-open
            Item {
                id: tileEyes
                visible: ov.hot
                anchors.right: parent.left
                anchors.rightMargin: chrome.px(12)
                anchors.verticalCenter: parent.verticalCenter
                width: chrome.px(20); height: chrome.px(7)
                transformOrigin: Item.Center
                onVisibleChanged: if (visible) openBlink.restart()
                Rectangle {
                    x: 0; y: chrome.px(1.5)
                    width: chrome.px(7); height: chrome.px(5); radius: height / 2
                    color: chrome.pal.cyan
                    Rectangle { x: chrome.px(2); y: chrome.px(1); width: chrome.px(2); height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.9) }
                }
                Rectangle {
                    x: chrome.px(13); y: 0
                    width: chrome.px(7); height: chrome.px(5); radius: height / 2
                    color: chrome.pal.cyan
                    Rectangle { x: chrome.px(2); y: chrome.px(1); width: chrome.px(2); height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.9) }
                }
                SequentialAnimation {
                    id: openBlink
                    NumberAnimation { target: tileEyes; property: "scaleY"; from: 0.08; to: 1; duration: 140; easing.type: Easing.OutQuint }
                }
                // the slow deliberate blink while it considers this one
                SequentialAnimation {
                    running: ov.hot && chrome.overview.open
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2600 }
                    NumberAnimation { target: tileEyes; property: "scaleY"; to: 0.08; duration: 70 }
                    NumberAnimation { target: tileEyes; property: "scaleY"; to: 1; duration: 120; easing.type: Easing.OutQuint }
                }
            }

            // the ember berry on the window you already hold
            Rectangle {
                visible: ov.ctr
                x: chrome.px(10)
                y: -chrome.px(4)
                width: chrome.px(8); height: width; radius: width / 2
                color: chrome.pal.neon
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
            }

            // a leaf lying over the watched tile's corner — cover follows you
            Canvas {
                visible: ov.hot
                anchors.fill: parent
                onVisibleChanged: if (visible) requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    ctx.save()
                    ctx.translate(width - chrome.px(2), chrome.px(3)); ctx.rotate(Math.PI - 0.7)
                    ctx.beginPath()
                    ctx.moveTo(0, 0)
                    ctx.quadraticCurveTo(chrome.px(10), -chrome.px(7), chrome.px(24), -chrome.px(2))
                    ctx.quadraticCurveTo(chrome.px(11), chrome.px(6), 0, 0)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(5,9,7,0.92)"
                    ctx.fill()
                    ctx.restore()
                }
            }
        }
    }
}
