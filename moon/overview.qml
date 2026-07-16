import QtQuick

// Cyberpunk: Edgerunners TARGET.GRID chrome for the Super+Tab exposé.
//
// The shell keeps the radial layout, live thumbnails and nav; this file turns
// it into a netrunner target-acquisition HUD: chamfered chassis tiles wired to
// the center by grid spokes, a rotating sweep reticle behind the focused
// window, corner readouts (signal count, azimuth of the current lock), CRT
// scanlines over everything, and a snap-in targeting bracket + RGB-split
// glitch on whichever tile the cursor acquires. Same HUD grammar as
// moon/popup.qml and moon/sysinfo.qml — chamfer, fake-glow double stroke,
// cyan L-brackets, magenta corner ticks.
//
// Visual-only by contract: no input handlers anywhere; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale

    // ── scalars: kill the glass, the chassis draws its own everything ──
    readonly property color scrimColor: "#04040a"
    readonly property real scrimOpacity: 0.62
    readonly property bool shadowOn: false
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property color cardBorderHot: "transparent"
    readonly property color cardBorderCenter: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardBorderWidthHot: 0
    readonly property int cardBorderWidthCenter: 0
    readonly property int cardRadius: 0
    readonly property color cardHighlight: "transparent"
    readonly property color thumbBg: "#07070c"
    readonly property int thumbRadius: 0
    readonly property color titleColor: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.75)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.8)
    readonly property string hintText: "◄ ► ▲ ▼  ACQUIRE      ↵  JACK IN      ESC  ABORT"
    readonly property string emptyText: "// NO SIGNALS ON GRID"

    // azimuth of the current lock, HUD-style (12 o'clock = 000.0)
    readonly property string azText: {
        const ts = overview.tiles
        const i = overview.selected
        if (i < 0 || i >= ts.length) return "---.-"
        const t = ts[i]
        if (t.center) return "000.0"
        let deg = Math.atan2(t.ry, t.rx) * 180 / Math.PI + 90
        if (deg < 0) deg += 360
        return (deg < 100 ? (deg < 10 ? "00" : "0") : "") + deg.toFixed(1)
    }

    // ── backdrop: grid spokes + rings + corner readouts + boot glitch ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // spokes from screen center out to each tile's live position; the
            // acquired tile's spoke burns neon, the rest stay dim traces. Also
            // a dashed ring through the tile orbit and a faint inner ring.
            Canvas {
                id: spokes
                anchors.fill: parent
                opacity: 0.9
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { spokes.requestPaint() }
                    function onTilesChanged() { spokes.requestPaint() }
                    function onSelectedChanged() { spokes.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { spokes.requestPaint() }
                    function onCyanChanged() { spokes.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const rv = chrome.overview.reveal
                    const ts = chrome.overview.tiles
                    // spokes
                    for (let i = 0; i < ts.length; i++) {
                        if (ts[i].center) continue
                        const hot = i === chrome.overview.selected
                        ctx.beginPath()
                        ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + ts[i].rx * rv, cy + ts[i].ry * rv)
                        ctx.strokeStyle = hot ? chrome.pal.neon : chrome.pal.cyan
                        ctx.globalAlpha = hot ? 0.5 : 0.13
                        ctx.lineWidth = hot ? 1.4 : 1
                        ctx.stroke()
                    }
                    // dashed orbit ring through the tile centers
                    const R = chrome.overview.ringRadius * rv
                    if (R > 10) {
                        ctx.globalAlpha = 0.22
                        ctx.strokeStyle = chrome.pal.cyan
                        ctx.lineWidth = 1
                        const segs = 48
                        for (let s = 0; s < segs; s++) {
                            const a0 = s * 2 * Math.PI / segs
                            const a1 = a0 + 0.6 * 2 * Math.PI / segs
                            ctx.beginPath()
                            ctx.arc(cx, cy, R, a0, a1)
                            ctx.stroke()
                        }
                        // faint inner ring
                        ctx.globalAlpha = 0.1
                        ctx.beginPath()
                        ctx.arc(cx, cy, R * 0.45, 0, 2 * Math.PI)
                        ctx.stroke()
                    }
                }
            }

            // rotating sweep reticle behind the focused (center) tile — a
            // dashed arc ring with a bright leading tick. Rotation is a GPU
            // transform, the canvas paints once.
            Item {
                anchors.centerIn: parent
                width: 300 * chrome.overview.reveal
                height: width
                opacity: 0.5 * chrome.overview.reveal
                visible: chrome.overview.tiles.length > 0

                Canvas {
                    id: sweep
                    anchors.fill: parent
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    Connections {
                        target: chrome.pal
                        function onNeonChanged() { sweep.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width < 20) return
                        const c = width / 2, r = width / 2 - 4
                        ctx.strokeStyle = chrome.pal.neon
                        // three long arcs with gaps
                        ctx.globalAlpha = 0.55
                        ctx.lineWidth = 1.2
                        for (let s = 0; s < 3; s++) {
                            const a0 = s * 2 * Math.PI / 3
                            ctx.beginPath()
                            ctx.arc(c, c, r, a0, a0 + 1.7)
                            ctx.stroke()
                        }
                        // leading tick
                        ctx.globalAlpha = 1
                        ctx.lineWidth = 3
                        ctx.beginPath()
                        ctx.arc(c, c, r, -0.08, 0.08)
                        ctx.stroke()
                    }
                    RotationAnimation on rotation {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 9000
                    }
                }
            }

            // screen-corner L-brackets — the whole monitor becomes the HUD frame
            Repeater {
                model: [
                    { lx: true,  ty: true  }, { lx: false, ty: true  },
                    { lx: true,  ty: false }, { lx: false, ty: false }
                ]
                delegate: Item {
                    required property var modelData
                    readonly property int m: Math.round(26 * chrome.ui)
                    width: Math.round(34 * chrome.ui); height: width
                    x: modelData.lx ? m : bd.width - width - m
                    y: modelData.ty ? m : bd.height - height - m
                    opacity: 0.6 * chrome.overview.reveal
                    Rectangle {
                        width: parent.width; height: 2
                        color: chrome.pal.cyan
                        y: parent.modelData.ty ? 0 : parent.height - height
                    }
                    Rectangle {
                        width: 2; height: parent.height
                        color: chrome.pal.cyan
                        x: parent.modelData.lx ? 0 : parent.width - width
                    }
                }
            }

            // ── corner readouts ──
            // top-left: pip + TARGET.GRID + signal count
            Row {
                x: Math.round(30 * chrome.ui); y: Math.round(32 * chrome.ui)
                spacing: 8
                opacity: chrome.overview.reveal

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 1
                    color: chrome.pal.magenta
                    SequentialAnimation on opacity {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 650 }
                        NumberAnimation { to: 1.0; duration: 650 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TARGET.GRID"
                    font.family: chrome.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(13 * chrome.ui)
                    font.letterSpacing: 4
                    color: chrome.pal.neon
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "// SIG " + String(chrome.overview.windows.length).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.pal.cyan
                    opacity: 0.8
                }
            }

            // top-right: sector-scan tag
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(30 * chrome.ui)
                y: Math.round(34 * chrome.ui)
                text: "// SECTOR SCAN : EXPOSÉ"
                font.family: chrome.mono
                font.pixelSize: Math.round(9 * chrome.ui)
                font.letterSpacing: 2
                color: chrome.pal.cyan
                opacity: 0.6 * chrome.overview.reveal
            }

            // bottom-left: live lock telemetry
            Column {
                x: Math.round(30 * chrome.ui)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(30 * chrome.ui)
                spacing: 3
                opacity: 0.85 * chrome.overview.reveal

                Text {
                    text: "LOCK " + (chrome.overview.selected >= 0
                        ? String(chrome.overview.selected).padStart(2, "0") : "--")
                        + "/" + String(chrome.overview.tiles.length).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.pal.neon
                }
                Text {
                    text: "AZ  " + chrome.azText + "°"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.pal.cyan
                    opacity: 0.8
                }
                Text {
                    text: "// NETRUNNER EXPO"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(8 * chrome.ui)
                    font.letterSpacing: 2
                    color: chrome.pal.dim
                }
            }

            // boot glitch: three slabs tear across the screen as the grid
            // spins up, once per open (the backdrop remounts each open).
            Repeater {
                model: [
                    { yf: 0.22, col: chrome.pal.magenta, d0: 0 },
                    { yf: 0.55, col: chrome.pal.cyan,    d0: 60 },
                    { yf: 0.78, col: chrome.pal.neon,    d0: 110 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    y: bd.height * modelData.yf
                    height: 2
                    color: modelData.col
                    opacity: 0
                    x: 0; width: bd.width
                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: modelData.d0 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0.35; duration: 30 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0; duration: 160 }
                    }
                }
            }
        }
    }

    // ── per-tile chassis: chamfered dark plate, fake-glow neon edge ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load

            Canvas {
                id: chassis
                anchors.fill: parent
                Component.onCompleted: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: ur.tile
                    function onHotChanged() { chassis.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { chassis.requestPaint() }
                    function onCyanChanged() { chassis.requestPaint() }
                    function onMagentaChanged() { chassis.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, c = 12
                    const hot = ur.tile && ur.tile.hot
                    const ctr = ur.tile && ur.tile.isCenter
                    ctx.beginPath()
                    ctx.moveTo(c, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - c)
                    ctx.lineTo(w - c, h); ctx.lineTo(0, h); ctx.lineTo(0, c)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(7,7,12,0.93)"
                    ctx.fill()
                    // fake glow: wide low-alpha stroke, then the crisp edge
                    const edge = hot ? chrome.pal.neon : (ctr ? chrome.pal.neon : chrome.pal.cyan)
                    ctx.strokeStyle = edge
                    ctx.lineWidth = 3
                    ctx.globalAlpha = hot ? 0.3 : 0.12
                    ctx.stroke()
                    ctx.globalAlpha = hot ? 1 : (ctr ? 0.85 : 0.55)
                    ctx.lineWidth = hot ? 1.6 : 1.2
                    ctx.stroke()
                    // magenta corner tick, bottom-right (the house signature)
                    ctx.globalAlpha = hot || ctr ? 1 : 0.6
                    ctx.beginPath()
                    ctx.moveTo(w - 4, h - 18); ctx.lineTo(w - 4, h - 5); ctx.lineTo(w - 17, h - 5)
                    ctx.strokeStyle = chrome.pal.magenta
                    ctx.lineWidth = 1.5
                    ctx.stroke()
                }
            }
        }
    }

    // ── per-tile HUD dressing: class tag, hex id, focus tag, and the
    // snap-in targeting bracket + RGB-split glitch on acquisition ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            onHotChanged: if (hot) { snap.restart(); glitch.restart() }

            // signal tag riding the top edge: window class, uppercased
            Rectangle {
                x: 10
                y: -7
                width: sigText.width + 12
                height: 14
                color: "#07070c"
                border.color: ov.hot ? chrome.pal.neon : chrome.pal.dim
                border.width: 1
                Text {
                    id: sigText
                    anchors.centerIn: parent
                    text: "SIG." + ((ov.tile && ov.tile.win.cls) ? ov.tile.win.cls : "UNKNOWN").toUpperCase()
                    textFormat: Text.PlainText
                    font.family: chrome.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                    color: ov.hot ? chrome.pal.neon : chrome.pal.cyan
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, (ov.tile ? ov.tile.width : 100) - 40)
                }
            }

            // hex index chip, bottom-right, clear of the magenta tick
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                text: "0x" + (ov.tile ? ov.tile.index : 0).toString(16).toUpperCase().padStart(2, "0")
                font.family: chrome.mono
                font.pixelSize: 8
                color: chrome.pal.dim
            }

            // the focused window's crown tag
            Text {
                visible: ov.ctr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: 6
                text: "// FOCUSED"
                font.family: chrome.mono
                font.pixelSize: 9
                font.letterSpacing: 3
                color: chrome.pal.magenta
                opacity: 0.9
            }

            // targeting brackets: four L-corners that snap in from outside
            Item {
                id: bracket
                anchors.fill: parent
                visible: ov.hot
                scale: 1
                SequentialAnimation {
                    id: snap
                    running: false
                    NumberAnimation { target: bracket; property: "scale"; from: 1.18; to: 0.985; duration: 110; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bracket; property: "scale"; to: 1; duration: 90; easing.type: Easing.OutBack }
                }
                Repeater {
                    model: [
                        { lx: true,  ty: true  }, { lx: false, ty: true  },
                        { lx: true,  ty: false }, { lx: false, ty: false }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: 14; height: 14
                        x: modelData.lx ? -5 : bracket.width - width + 5
                        y: modelData.ty ? -5 : bracket.height - height + 5
                        Rectangle {
                            width: parent.width; height: 2
                            color: chrome.pal.neon
                            y: parent.modelData.ty ? 0 : parent.height - height
                        }
                        Rectangle {
                            width: 2; height: parent.height
                            color: chrome.pal.neon
                            x: parent.modelData.lx ? 0 : parent.width - width
                        }
                    }
                }
                // crosshair ticks, mid-edge
                Rectangle { width: 7; height: 1.5; color: chrome.pal.neon; anchors.verticalCenter: parent.verticalCenter; x: -8 }
                Rectangle { width: 7; height: 1.5; color: chrome.pal.neon; anchors.verticalCenter: parent.verticalCenter; x: parent.width + 1 }
                Rectangle { width: 1.5; height: 7; color: chrome.pal.neon; anchors.horizontalCenter: parent.horizontalCenter; y: -8 }
                Rectangle { width: 1.5; height: 7; color: chrome.pal.neon; anchors.horizontalCenter: parent.horizontalCenter; y: parent.height + 1 }
            }

            // acquisition glitch: cyan/magenta ghost frames split apart and
            // collapse the instant a tile goes hot
            Item {
                anchors.fill: parent
                Rectangle {
                    id: ghostM
                    anchors.fill: parent
                    color: "transparent"
                    border.color: chrome.pal.magenta
                    border.width: 1
                    opacity: 0
                }
                Rectangle {
                    id: ghostC
                    anchors.fill: parent
                    color: "transparent"
                    border.color: chrome.pal.cyan
                    border.width: 1
                    opacity: 0
                }
                ParallelAnimation {
                    id: glitch
                    running: false
                    SequentialAnimation {
                        PropertyAction { target: ghostM; property: "x"; value: -3 }
                        NumberAnimation { target: ghostM; property: "opacity"; to: 0.7; duration: 30 }
                        NumberAnimation { target: ghostM; property: "x"; to: 0; duration: 120 }
                        NumberAnimation { target: ghostM; property: "opacity"; to: 0; duration: 60 }
                    }
                    SequentialAnimation {
                        PropertyAction { target: ghostC; property: "x"; value: 3 }
                        NumberAnimation { target: ghostC; property: "opacity"; to: 0.7; duration: 30 }
                        NumberAnimation { target: ghostC; property: "x"; to: 0; duration: 120 }
                        NumberAnimation { target: ghostC; property: "opacity"; to: 0; duration: 60 }
                    }
                }
            }
        }
    }

    // ── overlay: CRT scanlines over the whole grid + edge rules ──
    readonly property Component overlay: Component {
        Item {
            Canvas {
                anchors.fill: parent
                opacity: 0.3
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "rgba(0,0,0,0.5)"
                    ctx.lineWidth = 1
                    for (let y = 3; y < height; y += 3) {
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                    }
                }
            }
            // hairline chroma rules top and bottom — the CRT bezel edge
            Rectangle {
                anchors.top: parent.top
                width: parent.width; height: 1
                color: chrome.pal.cyan
                opacity: 0.35 * chrome.overview.reveal
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: chrome.pal.magenta
                opacity: 0.3 * chrome.overview.reveal
            }
        }
    }
}
