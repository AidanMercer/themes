import QtQuick

// shiro: washi chrome for the Super+Tab exposé. The desktop dims to paper,
// the windows become washi cards, and a single enso brushes itself in around
// the focused window — the poem writing itself. The shell keeps the layout,
// live thumbnails and nav; this file only quiets the light. Nothing loops.
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function toWhite(c, t) {
        return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, 1)
    }
    readonly property color paper: toWhite(pal.glass, 0.55)

    // ── scrim: the desktop dims to paper, not to night ──
    readonly property color scrimColor: pal.glass
    readonly property real scrimOpacity: 0.5

    // ── washi cards: white paper, ink hairline, blush-gray shadow ──
    readonly property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.96)
    readonly property color cardBorder: inkA(0.2)
    readonly property color cardBorderHot: wisteria
    readonly property color cardBorderCenter: inkA(0.34)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: Math.round(14 * ui)
    readonly property color cardHighlight: "transparent"   // paper has no gloss
    readonly property bool shadowOn: true
    readonly property color shadowColor: Qt.rgba(
        (blush.r + pal.dim.r) / 2, (blush.g + pal.dim.g) / 2,
        (blush.b + pal.dim.b) / 2, 0.22)
    readonly property color thumbBg: inkA(0.05)             // whisper-gray inset
    readonly property int thumbRadius: Math.round(9 * ui)

    // ── ink voice ──
    readonly property color titleColor: inkA(0.62)
    readonly property color titleHotColor: ink              // the title ink darkens
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: inkA(0.5)
    readonly property string hintText: "choose a window — 選ぶ"
    readonly property string emptyText: "白 — nothing open"

    // ── backdrop: one gesture — an enso brushed around the center tile,
    // drawing itself in once per open (the backdrop remounts each open) ──
    readonly property Component backdrop: Component {
        Item {
            Canvas {
                id: enso
                anchors.centerIn: parent
                width: Math.ceil(chrome.overview.ringRadius * 0.5 + 26 * chrome.ui) * 2
                height: width
                visible: chrome.overview.tiles.length > 0

                // the brush's travel, 0 → 1 over ~600ms — one-shot, no loop
                property real prog: 0
                NumberAnimation on prog {
                    from: 0; to: 1
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                // radius rides the shell's zoom-out so the ring lands with the tiles
                readonly property real r: chrome.overview.ringRadius * 0.5 * chrome.overview.reveal

                onProgChanged: requestPaint()
                onRChanged: requestPaint()
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onTextChanged() { enso.requestPaint() }
                    function onDimChanged() { enso.requestPaint() }
                    function onCyanChanged() { enso.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = enso.r
                    if (r < 8 || prog <= 0) return
                    const c = width / 2
                    ctx.lineCap = "round"
                    const start = -Math.PI * 0.55              // brush lands upper-left
                    const sweep = Math.PI * 5 / 3 * prog       // 300°, the traditional gap
                    const steps = Math.max(8, Math.round(56 * prog))
                    // dry-brush body: three passes, slightly offset radius and alpha
                    const passes = [
                        { col: chrome.ink,     dr: 0,    a: 0.13, w: 1.0 },
                        { col: chrome.pal.dim, dr: 2.4,  a: 0.07, w: 0.7 },
                        { col: chrome.pal.dim, dr: -1.9, a: 0.05, w: 0.6 }
                    ]
                    for (let p = 0; p < passes.length; p++) {
                        const ps = passes[p]
                        for (let i = 0; i < steps; i++) {
                            const t = i / steps
                            ctx.beginPath()
                            ctx.arc(c, c, r + ps.dr * chrome.ui,
                                    start + sweep * t, start + sweep * (t + 1 / steps) + 0.012)
                            // pressure: heavy where the brush lands, thinning to the
                            // lift, with a little hand-wobble so it reads brushed
                            ctx.lineWidth = Math.max(0.5,
                                (1 + 4.6 * Math.pow(1 - t, 1.3) * ps.w
                                   + Math.sin(t * 9 + p) * 0.5) * chrome.ui)
                            ctx.strokeStyle = Qt.rgba(ps.col.r, ps.col.g, ps.col.b,
                                                      ps.a * (1 - t * 0.45))
                            ctx.stroke()
                        }
                    }
                    // the first touch of the brush — one blush point
                    ctx.beginPath()
                    ctx.arc(c + r * Math.cos(start), c + r * Math.sin(start),
                            2.2 * chrome.ui, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(chrome.blush.r, chrome.blush.g, chrome.blush.b,
                                            0.45 * Math.min(1, prog * 3))
                    ctx.fill()
                }
            }
        }
    }

    // ── per-tile mark: a tiny ink touten above the focused tile, nothing more ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null   // injected by the shell after load

            Text {
                visible: ov.tile ? ov.tile.isCenter === true : false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(2 * chrome.ui)
                text: "、"
                textFormat: Text.PlainText
                font.family: chrome.serif
                font.pixelSize: Math.round(15 * chrome.ui)
                color: chrome.inkA(0.55)
                opacity: chrome.overview.reveal
            }
        }
    }
}
