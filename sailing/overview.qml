import QtQuick

// sailing: the compass rose — chrome for the Super+Tab exposé. The ring of
// windows IS the rose: faint compass ticks around the orbit (long marks at
// the cardinals), a stitched rope-line circle through the tile centers, and
// a quiet serif "N" riding just outside twelve o'clock. Tiles are cabin
// charts — deep navy glass, hairline slate border, brass L-corners; the hot
// one takes the lifebuoy's red-orange and a one-shot deck-roll settle, the
// focused one holds a small brass helm above it, steady.
//
// Visual-only by contract: no input handlers; nothing loops (the roll is a
// one-shot on hot), so an idle exposé costs nothing.
Item {
    id: chrome

    required property var pal        // theme palette — neon/cyan/magenta/amber/dim…
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property color buoy:  pal.neon      // lifebuoy red-orange, sparingly
    readonly property color dusk:  pal.cyan      // lavender-pink horizon
    readonly property color lamp:  pal.amber     // brass / deck lamp
    readonly property color slate: pal.dim       // rain-gray railings
    readonly property color pale:  pal.text      // breath on cold glass
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }

    // ── scalars: cabin-chart cards on a dark-water scrim ────────────────────
    readonly property color scrimColor: Qt.darker(glass, 2.0)
    readonly property real scrimOpacity: 0.55
    readonly property color cardBg: Qt.rgba(glass.r, glass.g, glass.b, 0.92)
    readonly property color cardBorder: slateA(0.55)          // hairline slate
    readonly property color cardBorderHot: buoy               // the lifebuoy
    readonly property color cardBorderCenter: lampA(0.6)      // brass, at the helm
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 8
    readonly property color cardHighlight: paleA(0.07)
    readonly property color thumbBg: Qt.darker(glass, 1.5)
    readonly property int thumbRadius: 6
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.45)
    readonly property color titleColor: paleA(0.72)
    readonly property color titleHotColor: pale
    readonly property string titleFont: mono
    readonly property string hintFont: mono
    readonly property color hintColor: duskA(0.85)
    readonly property string hintText: "helm: arrows · enter to board · esc back to bunk"
    readonly property string emptyText: "becalmed — no windows"

    // ── backdrop: the rose — ticks, rope line, and the N ────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: rose
                anchors.fill: parent
                opacity: 0.9
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { rose.requestPaint() }
                    function onTilesChanged() { rose.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onDimChanged() { rose.requestPaint() }
                    function onAmberChanged() { rose.requestPaint() }
                    function onTextChanged() { rose.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width < 2 || height < 2) return
                    const cx = width / 2, cy = height / 2
                    const R = chrome.overview.ringRadius * chrome.overview.reveal
                    if (R < 12) return

                    // rope line stitched through the orbit — short dashes, like
                    // a course plotted around the rose
                    ctx.strokeStyle = chrome.pale
                    ctx.globalAlpha = 0.15
                    ctx.lineWidth = 1
                    const segs = 72
                    for (let s = 0; s < segs; s++) {
                        const a0 = s * 2 * Math.PI / segs
                        ctx.beginPath()
                        ctx.arc(cx, cy, R, a0, a0 + 0.62 * 2 * Math.PI / segs)
                        ctx.stroke()
                    }

                    // compass ticks just outside the orbit: 64 marks, brass
                    // cardinals, pale half-winds, slate minors
                    const r1 = R + Math.round(10 * chrome.ui)
                    for (let i = 0; i < 64; i++) {
                        const a = -Math.PI / 2 + i * 2 * Math.PI / 64
                        const cardinal = i % 16 === 0
                        const half = !cardinal && i % 8 === 0
                        const len = (cardinal ? 15 : half ? 9 : 5) * chrome.ui
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                        ctx.lineTo(cx + Math.cos(a) * (r1 + len), cy + Math.sin(a) * (r1 + len))
                        ctx.strokeStyle = cardinal ? chrome.lamp : half ? chrome.pale : chrome.slate
                        ctx.globalAlpha = cardinal ? 0.75 : half ? 0.4 : 0.45
                        ctx.lineWidth = cardinal ? 1.6 : 1
                        ctx.stroke()
                    }
                }
            }

            // the N, quiet in dusk lavender, just past the twelve o'clock tick
            Text {
                x: bd.width / 2 - width / 2
                y: bd.height / 2 - chrome.overview.ringRadius * chrome.overview.reveal
                   - height - Math.round(30 * chrome.ui)
                text: "N"
                color: chrome.duskA(0.85)
                font.family: chrome.serif
                font.pixelSize: Math.round(17 * chrome.ui)
                opacity: chrome.overview.reveal
            }
        }
    }

    // ── per-tile: brass corners + chart number, deck-roll on hot ────────────
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null   // injected by the shell after load
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the hot chart takes the deck's roll — a small sway that damps to
            // rest, once per acquisition; steadied the moment it goes cold
            onHotChanged: {
                if (hot) roll.restart()
                else { roll.stop(); frame.rotation = 0 }
            }

            Item {
                id: frame
                anchors.fill: parent

                SequentialAnimation {
                    id: roll
                    running: false
                    NumberAnimation { target: frame; property: "rotation"; from: -1.4; to: 0.8; duration: 480; easing.type: Easing.InOutSine }
                    NumberAnimation { target: frame; property: "rotation"; from: 0.8; to: -0.3; duration: 420; easing.type: Easing.InOutSine }
                    NumberAnimation { target: frame; property: "rotation"; from: -0.3; to: 0; duration: 340; easing.type: Easing.OutSine }
                }

                // four brass L-corners — the chart's frame fittings
                Repeater {
                    model: [
                        { lx: true,  ty: true  }, { lx: false, ty: true  },
                        { lx: true,  ty: false }, { lx: false, ty: false }
                    ]
                    delegate: Item {
                        required property var modelData
                        readonly property int arm: Math.round(12 * chrome.ui)
                        width: arm; height: arm
                        x: modelData.lx ? -2 : frame.width - width + 2
                        y: modelData.ty ? -2 : frame.height - height + 2
                        Rectangle {
                            width: parent.width; height: 1.5
                            color: chrome.lampA(ov.hot ? 0.95 : 0.6)
                            y: parent.modelData.ty ? 0 : parent.height - height
                        }
                        Rectangle {
                            width: 1.5; height: parent.height
                            color: chrome.lampA(ov.hot ? 0.95 : 0.6)
                            x: parent.modelData.lx ? 0 : parent.width - width
                        }
                    }
                }

                // chart number tab, top-right, above the frame
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 3
                    text: "no. " + String((ov.tile ? ov.tile.index : 0) + 1).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(8 * chrome.ui)
                    font.letterSpacing: 1
                    color: chrome.slateA(0.95)
                }
            }

            // at the helm: a small brass wheel above the focused chart — this
            // one holds steady, outside the rolling frame
            Canvas {
                id: helm
                visible: ov.ctr
                width: Math.round(20 * chrome.ui)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(7 * chrome.ui)
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onAmberChanged() { helm.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width < 4) return
                    const c = width / 2
                    ctx.strokeStyle = chrome.lampA(0.9)
                    ctx.lineWidth = 1.4
                    // rim
                    ctx.beginPath(); ctx.arc(c, c, c * 0.55, 0, 2 * Math.PI); ctx.stroke()
                    // four spokes, run out past the rim as handles
                    for (let i = 0; i < 4; i++) {
                        const a = i * Math.PI / 2
                        ctx.beginPath()
                        ctx.moveTo(c, c)
                        ctx.lineTo(c + Math.cos(a) * c * 0.9, c + Math.sin(a) * c * 0.9)
                        ctx.stroke()
                    }
                    // hub
                    ctx.beginPath(); ctx.arc(c, c, 1.6, 0, 2 * Math.PI)
                    ctx.fillStyle = chrome.lampA(0.95); ctx.fill()
                }
            }
        }
    }
}
