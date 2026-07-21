import QtQuick

// pines: chrome for the Super+Tab exposé. The shell keeps the radial
// layout, thumbnails and nav; this file lays the round out on the lookout's
// plane table: a compass ring with degree ticks and cardinal letters inked
// at the tile orbit, pencil bearing lines running from the table's center
// to every window (the selection's bearing inked in lamplight), a live
// bearing readout in the corner, and each window mounted as a map sheet —
// the hot sheet takes a surveyor's pin (a benchmark triangle condensing in
// at its head). No sweep, no glitch: pencil, paper, and one warm lamp.
//
// Visual-only by contract: no input handlers; loops gate on overview.open.
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    function lampA(a)   { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function silverA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    // ── scalars: map sheets on slate ───────────────────────────────────────
    // #050e16 / #071119: the wallpaper's pine-black tiers, kept darker than
    // pal.glass on purpose — the table under the sheets, not the cab glass
    readonly property color scrimColor: "#050e16"
    readonly property real scrimOpacity: 0.68
    readonly property bool shadowOn: false
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.92)
    readonly property color cardBorder: silverA(0.30)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: silverA(0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 3
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#071119"
    readonly property int thumbRadius: 2
    readonly property color titleColor: silverA(0.7)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: silverA(0.75)
    readonly property string hintText: "◄ ► ▲ ▼  move      ↵  focus      esc  close"
    readonly property string emptyText: "no open windows"

    // bearing of the current selection, plane-table style
    readonly property string brgText: {
        const ts = overview.tiles
        const i = overview.selected
        if (i < 0 || i >= ts.length) return "---"
        const t = ts[i]
        if (t.center) return "000"
        let deg = Math.atan2(t.rx, -t.ry) * 180 / Math.PI
        if (deg < 0) deg += 360
        return String(Math.round(deg)).padStart(3, "0")
    }

    // ── backdrop: compass ring + pencil bearings + corner readouts ─────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: table
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { table.requestPaint() }
                    function onTilesChanged() { table.requestPaint() }
                    function onSelectedChanged() { table.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { table.requestPaint() }
                    function onCyanChanged() { table.requestPaint() }
                    function onDimChanged() { table.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const rv = chrome.overview.reveal
                    const ts = chrome.overview.tiles

                    // pencil bearings out to every sighting
                    for (let i = 0; i < ts.length; i++) {
                        if (ts[i].center) continue
                        const hot = i === chrome.overview.selected
                        const tx = cx + ts[i].rx * rv, ty = cy + ts[i].ry * rv
                        const dx = tx - cx, dy = ty - cy
                        const len = Math.sqrt(dx * dx + dy * dy)
                        if (len < 1) continue
                        ctx.strokeStyle = hot ? chrome.pal.neon : chrome.pal.cyan
                        ctx.globalAlpha = hot ? 0.6 : 0.14
                        ctx.lineWidth = hot ? 1.3 : 1
                        // dashed by hand: draw segments along the bearing
                        const dash = 7, gapl = 5
                        let d = 12
                        ctx.beginPath()
                        while (d < len - 8) {
                            const e = Math.min(len - 8, d + dash)
                            ctx.moveTo(cx + dx * d / len, cy + dy * d / len)
                            ctx.lineTo(cx + dx * e / len, cy + dy * e / len)
                            d = e + gapl
                        }
                        ctx.stroke()
                    }

                    // the compass ring through the tile orbit
                    const R = chrome.overview.ringRadius * rv
                    if (R > 20) {
                        ctx.globalAlpha = 0.30
                        ctx.strokeStyle = chrome.pal.cyan
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                        ctx.stroke()
                        // degree ticks: fine every 6°, long every 30°
                        for (let a = 0; a < 360; a += 6) {
                            const long_ = a % 30 === 0
                            const th = (a - 90) * Math.PI / 180
                            const r0 = R - (long_ ? 10 : 5)
                            ctx.beginPath()
                            ctx.moveTo(cx + Math.cos(th) * r0, cy + Math.sin(th) * r0)
                            ctx.lineTo(cx + Math.cos(th) * R, cy + Math.sin(th) * R)
                            ctx.globalAlpha = long_ ? 0.35 : 0.18
                            ctx.stroke()
                        }
                        // cardinal letters just inside the ring
                        ctx.globalAlpha = 0.5
                        ctx.fillStyle = chrome.pal.cyan
                        ctx.font = Math.round(11 * chrome.ui) + 'px "' + chrome.mono + '"'
                        ctx.textAlign = "center"
                        ctx.textBaseline = "middle"
                        const rIn = R - 24
                        ctx.fillText("N", cx, cy - rIn)
                        ctx.fillText("E", cx + rIn, cy)
                        ctx.fillText("S", cx, cy + rIn)
                        ctx.fillText("W", cx - rIn, cy)
                        // faint station circle at the table's center
                        ctx.globalAlpha = 0.22
                        ctx.beginPath()
                        ctx.arc(cx, cy, R * 0.4, 0, 2 * Math.PI)
                        ctx.strokeStyle = chrome.pal.dim
                        ctx.stroke()
                    }
                }
            }

            // top-left: lamp pip + window count
            Row {
                x: Math.round(32 * chrome.ui); y: Math.round(32 * chrome.ui)
                spacing: 9
                opacity: chrome.overview.reveal

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: chrome.pal.neon
                    SequentialAnimation on opacity {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "windows " + String(chrome.overview.windows.length).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.silverA(0.85)
                }
            }

            // bottom-left: selection + bearing readout
            Column {
                x: Math.round(32 * chrome.ui)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(32 * chrome.ui)
                spacing: 3
                opacity: 0.9 * chrome.overview.reveal

                Text {
                    text: (chrome.overview.selected >= 0
                        ? String(chrome.overview.selected + 1).padStart(2, "0") : "--")
                        + "/" + String(chrome.overview.tiles.length).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.pal.neon
                }
                Text {
                    text: chrome.brgText + "°"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.silverA(0.8)
                }
            }
        }
    }

    // ── per-sheet dressing: class label, pin on the hot sheet ──────────────
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false

            // the sheet's label chip, riding the top edge
            Rectangle {
                x: 8
                y: -7
                width: clsText.width + 12
                height: 14
                radius: 2
                color: "#071119"   // pine-black, same tier tone as thumbBg
                border.color: ov.hot ? chrome.pal.neon : Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.9)
                border.width: 1
                Text {
                    id: clsText
                    anchors.centerIn: parent
                    text: ((ov.tile && ov.tile.win.cls) ? ov.tile.win.cls : "unknown").toUpperCase()
                    textFormat: Text.PlainText
                    font.family: chrome.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: ov.hot ? chrome.pal.neon : chrome.silverA(0.85)
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, (ov.tile ? ov.tile.width : 100) - 36)
                }
            }

            // the surveyor's pin: a benchmark condenses onto the hot sheet
            Canvas {
                id: pin
                visible: ov.hot
                anchors.horizontalCenter: parent.horizontalCenter
                y: -14
                width: 15; height: 12
                onVisibleChanged: if (visible) { requestPaint(); setPin.restart() }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { pin.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(width / 2, 1)
                    ctx.lineTo(width - 1, height - 1.5)
                    ctx.lineTo(1, height - 1.5)
                    ctx.closePath()
                    ctx.stroke()
                    ctx.fillStyle = chrome.pal.neon
                    ctx.fillRect(width / 2 - 1, height * 0.52, 2, 2)
                }
                SequentialAnimation {
                    id: setPin
                    ParallelAnimation {
                        NumberAnimation { target: pin; property: "scale"; from: 1.8; to: 1; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: pin; property: "opacity"; from: 0.2; to: 1; duration: 180 }
                    }
                }
            }

            // hairline corner ticks that light with the pin
            Repeater {
                model: [
                    { lx: true,  ty: true  }, { lx: false, ty: false }
                ]
                delegate: Item {
                    required property var modelData
                    visible: ov.hot
                    width: 10; height: 10
                    x: modelData.lx ? -3 : ov.width - width + 3
                    y: modelData.ty ? -3 : ov.height - height + 3
                    Rectangle {
                        width: parent.width; height: 1.3
                        color: chrome.pal.neon
                        y: parent.modelData.ty ? 0 : parent.height - height
                    }
                    Rectangle {
                        width: 1.3; height: parent.height
                        color: chrome.pal.neon
                        x: parent.modelData.lx ? 0 : parent.width - width
                    }
                }
            }
        }
    }

    // ── overlay: the thinnest breath of fog at the table's foot ────────────
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.18
                opacity: 0.5 * chrome.overview.reveal
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.05) }
                }
            }
        }
    }
}
