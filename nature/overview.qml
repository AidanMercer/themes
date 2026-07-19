import QtQuick

// nature — "golden hour" chrome for the Super+Tab exposé: the field journal,
// laid open. Every window is a specimen card pressed onto the page — cream
// paper on the deep-pine evening, washi tape across opposite corners, a
// second sheet peeking out behind. The cursor's card gets a honey-gold edge
// and a little daisy sticker; the focused window carries a pressed-leaf tick
// above it like the journal's current-page marker. Behind it all, a warm
// radial golden-hour wash and a few pollen motes drifting up through the
// light. Same paper-and-ink grammar as nature/sysinfo.qml.
//
// Visual-only by contract: no input handlers anywhere; every loop gates on
// overview.open (the shell tears these layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim…
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"

    // paper + ink derived from the palette so config.toml retints live
    // (same recipe as sysinfo.qml — the cards ARE journal pages)
    function toWhite(c, t) {
        return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, 1)
    }
    readonly property color paper: toWhite(cream, 0.4)
    readonly property color ink: Qt.rgba(pine.r * 0.75, pine.g * 0.75, pine.b * 0.75, 1)
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    readonly property color goldInk: Qt.darker(gold, 1.12)
    readonly property color leafInk: Qt.darker(leaf, 1.28)

    // ── scalars: cream specimen cards on a deep-pine evening ──
    readonly property color scrimColor: Qt.darker(pine, 1.35)
    readonly property real scrimOpacity: 0.58
    readonly property color shadowColor: Qt.rgba(pine.r * 0.25, pine.g * 0.25, pine.b * 0.2, 0.45)
    readonly property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.97)
    readonly property color cardBorder: Qt.alpha(leafInk, 0.45)      // thin sage ink
    readonly property color cardBorderHot: goldInk                   // honey-gold pick
    readonly property color cardBorderCenter: Qt.alpha(leafInk, 0.85)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 2
    readonly property int cardRadius: Math.round(8 * ui)
    readonly property color cardHighlight: Qt.alpha(toWhite(cream, 0.85), 0.55)
    readonly property color thumbBg: Qt.darker(paper, 1.08)          // light paper inset
    readonly property int thumbRadius: Math.round(6 * ui)
    readonly property color titleColor: inkA(0.82)                   // dark ink on cream
    readonly property color titleHotColor: goldInk
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: creamA(0.72)                  // hint sits on the scrim
    readonly property string hintText: "leaf through · enter to pick · esc close the journal"
    readonly property string emptyText: "nothing pressed between these pages"

    // ── backdrop: golden-hour wash + drifting pollen + the journal's header ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // warm radial vignette — honey-bright just above center, falling
            // off to pine-dark edges. paints once per size/palette change.
            Canvas {
                id: vig
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged()  { vig.requestPaint() }
                    function onGlassChanged() { vig.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    const cx = w / 2, cy = h * 0.42          // the low sun, a touch above center
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.hypot(w, h) * 0.55)
                    g.addColorStop(0.0, Qt.rgba(chrome.gold.r, chrome.gold.g, chrome.gold.b, 0.11))
                    g.addColorStop(0.4, Qt.rgba(chrome.gold.r, chrome.gold.g, chrome.gold.b, 0.03))
                    g.addColorStop(1.0, Qt.rgba(chrome.pine.r * 0.4, chrome.pine.g * 0.4, chrome.pine.b * 0.4, 0.5))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                }
            }

            // journal header — lowercase, like the page was titled by hand
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(40 * chrome.ui)
                text: "the field journal — " + chrome.overview.windows.length
                    + (chrome.overview.windows.length === 1 ? " specimen pressed" : " specimens pressed")
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: Math.round(14 * chrome.ui)
                font.letterSpacing: 1
                color: chrome.creamA(0.62)
                opacity: chrome.overview.reveal
            }

            // pollen motes climbing through the light — tiny, slow, few
            Repeater {
                model: [
                    { xf: 0.30, yf: 0.66, s: 3.2, drift: 110, d: 12000 },
                    { xf: 0.68, yf: 0.38, s: 2.4, drift: 90,  d: 15000 },
                    { xf: 0.52, yf: 0.78, s: 2.8, drift: 130, d: 18000 }
                ]
                delegate: Rectangle {
                    id: mote
                    required property var modelData
                    width: modelData.s * chrome.ui
                    height: width
                    radius: width / 2
                    color: Qt.alpha(chrome.gold, 0.85)
                    x: bd.width * modelData.xf
                    opacity: 0
                    SequentialAnimation {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        ParallelAnimation {
                            SequentialAnimation {
                                PropertyAction { target: mote; property: "y"; value: bd.height * mote.modelData.yf }
                                NumberAnimation {
                                    target: mote; property: "y"
                                    to: bd.height * mote.modelData.yf - mote.modelData.drift * chrome.ui
                                    duration: mote.modelData.d; easing.type: Easing.InOutSine
                                }
                            }
                            SequentialAnimation {
                                NumberAnimation { target: mote; property: "opacity"; to: 0.7; duration: mote.modelData.d * 0.35 }
                                NumberAnimation { target: mote; property: "opacity"; to: 0; duration: mote.modelData.d * 0.65 }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── under each card: the sheet beneath — a second page peeking out ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load

            Rectangle {
                anchors.fill: parent
                radius: chrome.cardRadius
                color: Qt.darker(chrome.paper, 1.14)
                border.width: 1
                border.color: chrome.inkA(0.14)
                // alternate the peek angle by index so the pile looks hand-laid
                rotation: ur.tile ? (ur.tile.index % 2 === 0 ? -1.8 : 2.1) : 1.5
                transformOrigin: Item.Center
                opacity: 0.85
            }
        }
    }

    // ── over each card: washi tape corners, daisy sticker, page-marker leaf ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            onHotChanged: if (hot) daisyPop.restart()

            // washi tape across opposite corners — the signature. translucent
            // apricot-cream strips, half on the card, half on the evening.
            Repeater {
                model: [
                    { tl: true,  rot: -12, a: 0.55 },
                    { tl: false, rot: 9,   a: 0.5 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.tl ? Math.round(-10 * chrome.ui) : ov.width - Math.round(32 * chrome.ui)
                    y: modelData.tl ? Math.round(-4 * chrome.ui) : ov.height - Math.round(9 * chrome.ui)
                    width: Math.round(42 * chrome.ui)
                    height: Math.round(13 * chrome.ui)
                    rotation: modelData.rot
                    color: Qt.alpha(chrome.toWhite(chrome.pal.amber, 0.45), modelData.a)
                    border.width: 1
                    border.color: chrome.creamA(0.28)
                }
            }

            // daisy sticker on the acquired card — gold heart, cream petals
            Canvas {
                id: daisy
                visible: ov.hot
                width: Math.round(24 * chrome.ui)
                height: width
                x: parent.width - width * 0.55
                y: -height * 0.4
                scale: 1
                SequentialAnimation {
                    id: daisyPop
                    running: false
                    NumberAnimation { target: daisy; property: "scale"; from: 0.3; to: 1.12; duration: 140; easing.type: Easing.OutCubic }
                    NumberAnimation { target: daisy; property: "scale"; to: 1; duration: 110; easing.type: Easing.OutBack }
                }
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { daisy.requestPaint() }
                    function onTextChanged() { daisy.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, r = width * 0.32
                    // five petal dashes
                    ctx.strokeStyle = chrome.toWhite(chrome.cream, 0.85)
                    ctx.lineWidth = 3 * chrome.ui
                    ctx.lineCap = "round"
                    for (let i = 0; i < 5; i++) {
                        const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                        ctx.beginPath()
                        ctx.moveTo(c + Math.cos(a) * r * 0.55, c + Math.sin(a) * r * 0.55)
                        ctx.lineTo(c + Math.cos(a) * r * 1.35, c + Math.sin(a) * r * 1.35)
                        ctx.stroke()
                    }
                    // honey heart
                    ctx.beginPath()
                    ctx.arc(c, c, r * 0.5, 0, Math.PI * 2)
                    ctx.fillStyle = chrome.gold
                    ctx.fill()
                }
            }

            // pressed-leaf tick above the focused window — the current page
            Canvas {
                id: pageLeaf
                visible: ov.ctr
                width: Math.round(26 * chrome.ui)
                height: Math.round(16 * chrome.ui)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(7 * chrome.ui)
                opacity: 0.9 * chrome.overview.reveal
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onCyanChanged() { pageLeaf.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    // a single sage leaf lying on its side, stem trailing left
                    ctx.strokeStyle = Qt.alpha(chrome.leaf, 0.8)
                    ctx.lineWidth = 1.2 * chrome.ui
                    ctx.beginPath()
                    ctx.moveTo(w * 0.05, h * 0.75)
                    ctx.quadraticCurveTo(w * 0.35, h * 0.65, w * 0.5, h * 0.5)
                    ctx.stroke()
                    ctx.save()
                    ctx.translate(w * 0.62, h * 0.42)
                    ctx.rotate(-0.35)
                    ctx.beginPath()
                    ctx.ellipse(-w * 0.22, -h * 0.28, w * 0.44, h * 0.56)
                    ctx.fillStyle = Qt.alpha(chrome.leaf, 0.85)
                    ctx.fill()
                    ctx.restore()
                }
            }
        }
    }
}
