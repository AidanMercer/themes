import QtQuick

// guts: manga-spread chrome for the Super+Tab exposé. The shell keeps the
// radial layout, thumbnails and nav; this file lays a paper wash over the
// desktop and turns every window into a printed panel — paper card, hard
// ink border, solid offset shadow like a pasted-down cel. The selected
// panel gets slashed across the corner in arterial red; the focused one
// carries a small Brand above it. Speedline ticks radiate along the spokes.
// Visual-only by contract: no input handlers, and it barely animates —
// one hard snap when a panel goes hot is the whole show.
Item {
    id: chrome

    required property var pal        // ink/blood palette from config.toml
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color paper: pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // ── scalars: paper spread, printed panels ──
    readonly property color scrimColor: paper
    readonly property real scrimOpacity: 0.8
    readonly property bool shadowOn: false          // we print our own, no blur
    readonly property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.98)
    readonly property color cardBorder: ink
    readonly property color cardBorderHot: fresh    // the cut runs red
    readonly property color cardBorderCenter: ink
    readonly property int cardBorderWidth: Math.max(1, Math.round(2 * ui))
    readonly property int cardBorderWidthHot: Math.max(1, Math.round(2 * ui))
    readonly property int cardBorderWidthCenter: Math.max(2, Math.round(3 * ui))
    readonly property int cardRadius: 0
    readonly property color cardHighlight: "transparent"   // no glass sheen on print
    readonly property color thumbBg: Qt.darker(paper, 1.07)
    readonly property int thumbRadius: 0
    readonly property color titleColor: inkA(0.78)
    readonly property color titleHotColor: blood
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: inkA(0.72)
    readonly property string hintText: "CHOOSE YOUR BATTLE — ↵ STRIKE   ESC SHEATHE"
    readonly property string emptyText: "NO FOES"

    // ── backdrop: speedline ticks along the ring spokes ──
    readonly property Component backdrop: Component {
        Item {
            Canvas {
                id: lines
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { lines.requestPaint() }
                    function onTilesChanged() { lines.requestPaint() }
                    function onSelectedChanged() { lines.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onTextChanged() { lines.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const rv = chrome.overview.reveal
                    const ts = chrome.overview.tiles
                    ctx.strokeStyle = chrome.ink
                    ctx.lineCap = "round"
                    // a few short dashes riding each spoke, drawn out by reveal;
                    // the hot spoke inks a touch darker so the eye finds it
                    for (let i = 0; i < ts.length; i++) {
                        if (ts[i].center) continue
                        const len = Math.hypot(ts[i].rx, ts[i].ry)
                        if (len < 1) continue
                        const ux = ts[i].rx / len, uy = ts[i].ry / len
                        const hot = i === chrome.overview.selected
                        ctx.globalAlpha = (hot ? 0.22 : 0.09) * rv
                        ctx.lineWidth = hot ? 1.5 : 1
                        for (let d = 0; d < 3; d++) {
                            // deterministic jitter per spoke/dash — hand-thrown, not measured
                            const j = Math.sin(i * 7.3 + d * 2.1) * 0.05
                            const r0 = len * (0.30 + d * 0.20 + j) * rv
                            const r1 = r0 + len * 0.10 * rv
                            ctx.beginPath()
                            ctx.moveTo(cx + ux * r0, cy + uy * r0)
                            ctx.lineTo(cx + ux * r1, cy + uy * r1)
                            ctx.stroke()
                        }
                    }
                }
            }
        }
    }

    // ── per-panel print: solid ink shadow, offset down-right, zero blur ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load

            Rectangle {
                readonly property real off: (ur.tile && ur.tile.hot ? 7 : 5) * chrome.ui
                x: off; y: off
                width: parent.width; height: parent.height
                color: chrome.ink
                // the panel lifts a hair when acquired — the shadow snaps out
                Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ── per-panel dressing: screentone corner, red slash on hot, Brand on center ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            onHotChanged: if (hot) slashSnap.restart()

            // screentone wedge, top-right — every panel gets its shading
            Canvas {
                id: tone
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: chrome.pal
                    function onTextChanged() { tone.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    ctx.fillStyle = chrome.inkA(0.12)
                    const rad = Math.min(w, h) * 0.30
                    for (let gy = 6; gy < rad; gy += 6) {
                        for (let gx = w - 6; gx > w - rad; gx -= 6) {
                            const dd = Math.hypot(w - gx, gy) / rad
                            if (dd > 1) continue
                            ctx.beginPath()
                            ctx.arc(gx + ((gy / 6) % 2 ? 3 : 0), gy, 1.3 * (1 - dd), 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }
            }

            // the slash: one arterial stroke across the top-left corner when hot
            Rectangle {
                id: slash
                visible: ov.hot
                width: 46 * chrome.ui
                height: 3.5 * chrome.ui
                x: -14 * chrome.ui
                y: 10 * chrome.ui
                rotation: -45
                antialiasing: true
                color: chrome.fresh
                SequentialAnimation {
                    id: slashSnap
                    running: false
                    PropertyAction { target: slash; property: "scale"; value: 0.2 }
                    NumberAnimation { target: slash; property: "scale"; to: 1.15; duration: 60; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slash; property: "scale"; to: 1; duration: 60 }
                }
            }

            // the Brand, small and red, hung above the focused panel
            Canvas {
                id: brand
                visible: ov.ctr
                width: Math.round(16 * chrome.ui)
                height: Math.round(24 * chrome.ui)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 8 * chrome.ui
                onVisibleChanged: if (visible) requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { brand.requestPaint() }
                }
                onPaint: {
                    // trimmed copy of the bar's brand glyph — same mark, tick size
                    const ctx = getContext("2d")
                    ctx.reset()
                    const s = height / 1.5, x = 1, y = 1
                    ctx.fillStyle = chrome.blood
                    ctx.strokeStyle = chrome.blood
                    ctx.lineWidth = Math.max(0.8, 0.09 * s)
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(x + 0.02 * s, y + 0.32 * s)
                    ctx.quadraticCurveTo(x + 0.10 * s, y + 0.02 * s, x + 0.38 * s, y)
                    ctx.quadraticCurveTo(x + 0.62 * s, y - 0.01 * s, x + 0.66 * s, y + 0.20 * s)
                    ctx.quadraticCurveTo(x + 0.68 * s, y + 0.34 * s, x + 0.52 * s, y + 0.44 * s)
                    ctx.quadraticCurveTo(x + 0.34 * s, y + 0.55 * s, x + 0.24 * s, y + 0.78 * s)
                    ctx.quadraticCurveTo(x + 0.14 * s, y + 1.00 * s, x + 0.14 * s, y + 1.22 * s)
                    ctx.quadraticCurveTo(x + 0.10 * s, y + 0.98 * s, x + 0.20 * s, y + 0.72 * s)
                    ctx.quadraticCurveTo(x + 0.28 * s, y + 0.50 * s, x + 0.40 * s, y + 0.36 * s)
                    ctx.quadraticCurveTo(x + 0.52 * s, y + 0.22 * s, x + 0.44 * s, y + 0.14 * s)
                    ctx.quadraticCurveTo(x + 0.34 * s, y + 0.06 * s, x + 0.20 * s, y + 0.16 * s)
                    ctx.quadraticCurveTo(x + 0.08 * s, y + 0.24 * s, x + 0.02 * s, y + 0.32 * s)
                    ctx.closePath()
                    ctx.fill(); ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(x + 0.50 * s, y + 0.30 * s)
                    ctx.quadraticCurveTo(x + 0.78 * s, y + 0.32 * s, x + 0.92 * s, y + 0.52 * s)
                    ctx.quadraticCurveTo(x + 0.70 * s, y + 0.46 * s, x + 0.46 * s, y + 0.42 * s)
                    ctx.closePath()
                    ctx.fill(); ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(x + 0.13 * s, y + 1.36 * s, 0.06 * s, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
