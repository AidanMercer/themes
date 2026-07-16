import QtQuick

// stars: the vending machine takes over the Super+Tab exposé. every open
// window is a product on a lit shelf — navy glass cards with the machine's
// signature shelf-light glowing under each one, a coin-slot code chip riding
// every tile (A1 A2 A3 B1…; the focused window already dropped, so its chip
// reads IN TRAY), and behind it all the quiet night: a few twinkling stars
// and one coral nebula drifting low in an upper corner. the shell keeps
// layout / thumbnails / nav; this file only dresses the machine.
//
// visual-only by contract — no input handlers; every loop gates on
// overview.open (the shell tears these layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=amber cyan=coral magenta=signal dim=slate
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function coralA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }
    // canvas gradient stops want css strings, not color values
    function cssA(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
             + Math.round(c.b * 255) + "," + a + ")"
    }

    // ── scalars: night scrim, shelf-item cards ──────────────────────────────
    readonly property color scrimColor: Qt.darker(pal.glass, 1.6)
    readonly property real scrimOpacity: 0.62
    readonly property bool shadowOn: true
    readonly property color shadowColor: {
        const c = Qt.darker(pal.glass, 2.2)
        return Qt.rgba(c.r, c.g, c.b, 0.6)
    }
    readonly property color cardBg: glassA(0.93)
    readonly property color cardBorder: slateA(0.6)
    readonly property color cardBorderHot: pal.neon          // the item lights up
    readonly property color cardBorderCenter: amberA(0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1              // subtle — color does the work
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 10
    readonly property color cardHighlight: inkA(0.07)        // starlight on the glass
    readonly property color thumbBg: Qt.darker(pal.glass, 1.4)
    readonly property int thumbRadius: 7
    readonly property color titleColor: inkA(0.68)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: amberA(0.6)
    readonly property string hintText: "insert coin · enter to vend · esc walk away"
    readonly property string emptyText: "sold out"

    // ── backdrop: twinkling stars + one coral nebula, up and out of the way ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // the nebula — a faint coral wash pooled in the upper-right sky.
            // painted once; repaints when the palette retints under it.
            Canvas {
                id: nebula
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onCyanChanged() { nebula.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width < 40 || height < 40) return
                    const cx = width * 0.85, cy = height * 0.08
                    const r = Math.min(width, height) * 0.7
                    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                    g.addColorStop(0, chrome.cssA(chrome.pal.cyan, 0.09))
                    g.addColorStop(0.5, chrome.cssA(chrome.pal.cyan, 0.03))
                    g.addColorStop(1, chrome.cssA(chrome.pal.cyan, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }

            // a handful of stars, mostly kept to the upper sky. positions
            // re-scatter each open (the backdrop remounts); pulses are slow,
            // desynced, and stop dead the moment the exposé closes.
            Repeater {
                model: 10
                delegate: Rectangle {
                    id: star
                    required property int index
                    readonly property real fx: Math.random()
                    readonly property real fy: Math.random() * 0.55
                    readonly property int tw: 1600 + Math.round(Math.random() * 2400)
                    x: Math.round(bd.width * fx)
                    y: Math.round(bd.height * fy)
                    width: Math.round((index % 3 === 0 ? 3 : 2) * chrome.ui)
                    height: width
                    radius: width / 2
                    // every fourth star burns vending-amber, the rest starlight
                    color: index % 4 === 0 ? chrome.amberA(0.9) : chrome.inkA(0.85)
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.85; duration: star.tw; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.2; duration: star.tw; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ── per-tile: the shelf light — an amber lamp line under the item and a
    // pool of warm light spilling a few px below the tile, like the strip
    // lamp under the bottles. brightens when the item is picked. ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load
            readonly property bool lit: ur.tile ? ur.tile.hot === true : false

            // the lamp itself, tucked just under the card's bottom edge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height
                width: parent.width - Math.round(16 * chrome.ui)
                height: Math.max(2, Math.round(2 * chrome.ui))
                radius: height / 2
                color: chrome.amberA(ur.lit ? 0.95 : 0.55)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            // the glow it throws down onto the shelf
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height + Math.round(2 * chrome.ui)
                width: parent.width - Math.round(6 * chrome.ui)
                height: Math.round(16 * chrome.ui)
                opacity: ur.lit ? 0.55 : 0.28
                Behavior on opacity { NumberAnimation { duration: 160 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.amberA(0.6) }
                    GradientStop { position: 1.0; color: chrome.amberA(0.0) }
                }
            }
        }
    }

    // ── per-tile: the coin-slot code chip + a punched star ──────────────────
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool lit: ov.tile ? ov.tile.hot === true : false
            readonly property bool ctr: ov.tile ? ov.tile.isCenter === true : false
            // ring tiles follow the center in the shell's list, so slot 0 = the
            // first item on the shelf; the focused window already vended
            readonly property int slotIdx: ov.tile ? Math.max(0, ov.tile.index - 1) : 0
            readonly property string code: ctr ? "IN TRAY"
                : String.fromCharCode(65 + Math.floor(slotIdx / 3) % 26) + (slotIdx % 3 + 1)

            // the chip rides the tile's top-left edge like a slot tag
            Rectangle {
                x: Math.round(10 * chrome.ui)
                y: -Math.round(8 * chrome.ui)
                width: codeText.implicitWidth + Math.round(12 * chrome.ui)
                height: Math.round(16 * chrome.ui)
                radius: 3
                color: chrome.glassA(0.97)
                border.width: 1
                border.color: ov.lit ? chrome.coralA(0.9) : chrome.slateA(0.85)
                Behavior on border.color { ColorAnimation { duration: 160 } }
                Text {
                    id: codeText
                    anchors.centerIn: parent
                    text: ov.code
                    font.family: chrome.mono
                    font.pixelSize: Math.round(9 * chrome.ui)
                    font.letterSpacing: 1
                    // amber digits; flips coral when the slot is picked
                    color: ov.lit ? chrome.pal.cyan : chrome.pal.neon
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            // the house signature, punched near the corner
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: Math.round(7 * chrome.ui)
                anchors.bottomMargin: Math.round(5 * chrome.ui)
                text: "✧"
                font.pixelSize: Math.round(9 * chrome.ui)
                color: chrome.inkA(ov.ctr ? 0.4 : 0.26)
            }
        }
    }
}
