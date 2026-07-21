import QtQuick

// bog: the Super+Tab exposé seen from above the pond. Every window is a
// thing afloat: each tile rests on its own elliptical lily-pad shadow, the
// hovered tile gets a cork float riding its edge and a slow ring spreading
// beneath it, and the focused window carries the raft's leaf-sail. The
// backdrop is the open water itself — rings drifting outward here and there,
// a few loose leaves turning on the surface. All folktale pace; every loop
// gates on overview.open. Visual-only by contract: no input handlers.
Item {
    id: chrome

    required property var pal        // neon=sunlit amber, cyan=moss, magenta=rust
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    function sunA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function mossA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function reedA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // ── scalars: soft pond glass, nothing sharp ──
    // scrim/thumb are the pond's deepest water — deliberately darker than
    // pal.glass and not retinted, like the painted murk they sit against
    readonly property color scrimColor: "#0b0d06"
    readonly property real scrimOpacity: 0.72
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    readonly property color cardBorder: mossA(0.5)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: mossA(0.9)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 14
    readonly property color cardHighlight: sunA(0.20)
    readonly property color thumbBg: "#0d0f08"
    readonly property int thumbRadius: 10
    readonly property bool shadowOn: false        // the lily-pad shadow below replaces it
    readonly property color titleColor: mossA(0.85)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: sunA(0.55)
    readonly property string hintText: "⏎ focus · esc close"
    readonly property string emptyText: "no windows"

    // deterministic scatter — the same pond on every mount
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // ── backdrop: open water with drifting rings and loose leaves ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // rings blooming here and there on the open water
            Repeater {
                model: 4
                Canvas {
                    id: ring
                    required property int index
                    property real t: 0
                    x: bd.width * (0.1 + chrome.rnd(index * 31 + 5) * 0.8) - 60
                    y: bd.height * (0.12 + chrome.rnd(index * 17 + 3) * 0.72)
                    width: 120; height: 42
                    onTChanged: requestPaint()
                    SequentialAnimation on t {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        PauseAnimation { duration: (ring.index * 1637) % 4200 }
                        NumberAnimation { from: 0; to: 1; duration: 5600 + (ring.index % 3) * 1400 }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const tt = t
                        if (tt <= 0 || tt >= 1) return
                        for (let k = 0; k < 2; k++) {
                            const t2 = (tt - k * 0.2) / (1 - k * 0.2)
                            if (t2 <= 0 || t2 >= 1) continue
                            const r = (width / 2) * (0.08 + 0.92 * t2)
                            ctx.save()
                            ctx.translate(width / 2, height / 2)
                            ctx.scale(1, 0.32)
                            ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                            ctx.restore()
                            ctx.strokeStyle = String(chrome.sunA(0.14 * (1 - t2)))
                            ctx.lineWidth = 1.2
                            ctx.stroke()
                        }
                    }
                }
            }

            // loose leaves turning slowly on the surface
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: bd.width * (0.06 + chrome.rnd(index * 47 + 11) * 0.88)
                    y: bd.height * (0.08 + chrome.rnd(index * 23 + 7) * 0.8)
                    width: 16 + chrome.rnd(index * 7) * 8
                    height: width * 0.5
                    radius: height / 2
                    color: index % 3 === 0 ? chrome.sunA(0.16) : chrome.mossA(0.18)
                    rotation: chrome.rnd(index * 13) * 360
                    SequentialAnimation on rotation {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: chrome.rnd(index * 13) * 360 + 14; duration: 6400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: chrome.rnd(index * 13) * 360 - 14; duration: 6400; easing.type: Easing.InOutSine }
                    }
                }
            }

            // the window count
            Text {
                x: 30; y: 26
                text: {
                    const n = chrome.overview.windows.length
                    return n + (n === 1 ? " window" : " windows")
                }
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: 15
                color: chrome.sunA(0.7)
            }
        }
    }

    // ── per-tile: the lily pad each window rests on ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: un
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false

            // the pad: a soft ellipse peeking out under the tile
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height * 0.4
                width: parent.width * 1.06
                height: Math.max(14, parent.height * 0.10)
                radius: height / 2
                color: un.hot ? chrome.mossA(0.42) : chrome.mossA(0.22)
                Behavior on color { ColorAnimation { duration: 400 } }
            }

            // the ring spreading under the pad you're drifting toward
            Canvas {
                id: hotRing
                visible: un.hot
                property real t: 0
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height * 0.5
                width: parent.width * 1.5
                height: Math.max(26, parent.height * 0.2)
                onTChanged: requestPaint()
                NumberAnimation on t {
                    from: 0; to: 1; duration: 2600
                    loops: Animation.Infinite
                    running: un.hot && chrome.overview.open
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const tt = t
                    if (tt <= 0 || tt >= 1) return
                    const r = (width / 2) * (0.55 + 0.45 * tt)
                    ctx.save()
                    ctx.translate(width / 2, height / 2)
                    ctx.scale(1, Math.max(0.08, height / width))
                    ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                    ctx.restore()
                    ctx.strokeStyle = String(chrome.sunA(0.30 * (1 - tt)))
                    ctx.lineWidth = 1.4
                    ctx.stroke()
                }
            }
        }
    }

    // ── per-tile: the cork float on the hovered pad, the sail on yours ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the cork float riding the hovered tile's left edge
            Item {
                id: cork
                visible: ov.hot
                x: -14
                anchors.verticalCenter: parent.verticalCenter
                width: 9; height: 13
                property real dip: 0
                transform: Translate { y: cork.dip }
                SequentialAnimation on dip {
                    running: ov.hot && chrome.overview.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 2; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -1; duration: 1500; easing.type: Easing.InOutSine }
                }
                Rectangle { x: 0; y: 0; width: 9; height: 5.5; radius: 2.7; color: chrome.pal.magenta }
                Rectangle { x: 1; y: 4.8; width: 7; height: 4.6; radius: 2.3; color: chrome.sunA(0.9) }
            }

            // the leaf-sail flying from the window you're on
            Item {
                visible: ov.ctr
                x: 10
                y: -12
                width: 16; height: 18
                Rectangle { x: 2; y: 0; width: 1.4; height: 16; color: chrome.reedA(1) }
                Rectangle { x: 3.5; y: 1; width: 10; height: 9; radius: 4.5; color: chrome.mossA(0.9) }
                Rectangle { x: 5; y: 3; width: 6; height: 1.2; radius: 0.6; color: chrome.sunA(0.6); rotation: 18 }
            }

            // a small title-stone at the bottom-right: the tile's number
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                text: String(ov.tile ? ov.tile.index + 1 : 1)
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: 11
                color: ov.hot ? chrome.pal.neon : chrome.reedA(0.9)
            }
        }
    }
}
