import QtQuick
import QtQuick.Particles

// avalon: chrome for the Super+Tab exposé — the meadow at dusk. The shell
// keeps the radial layout, live thumbnails and nav; this file pushes the
// bright flower field back with a moss vignette, sets the windows on
// moss-glass cards around a faint fairy ring, crowns the sleeping (focused)
// window with a gold blossom, and looses a few slow petals while you wander.
// Visual-only by contract: no input handlers anywhere; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim
    required property var overview   // exposé root — open, reveal, selected, tiles…

    // avalon speaks in leaf and gold, not neon
    readonly property color ivory: pal.text
    readonly property color gold:  pal.cyan
    readonly property color moss:  Qt.darker(pal.glass, 1.6)
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    // canvas gradient stops want css color strings, not qml colors
    function rgba(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }

    // ── scalars: moss glass, sage hairlines, gold only where chosen ──
    readonly property color scrimColor: moss
    readonly property real scrimOpacity: 0.5
    readonly property color cardBg: Qt.alpha(pal.glass, 0.90)
    readonly property color cardBorder: Qt.alpha(Qt.lighter(pal.dim, 1.4), 0.8)
    readonly property color cardBorderHot: gold
    readonly property color cardBorderCenter: goldA(0.5)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: Math.round(14 * ui)
    readonly property color cardHighlight: ivoryA(0.07)
    readonly property color thumbBg: Qt.alpha(moss, 0.9)
    readonly property int thumbRadius: Math.round(9 * ui)
    readonly property color shadowColor: Qt.alpha(Qt.darker(pal.glass, 2.2), 0.55)
    readonly property color titleColor: ivoryA(0.72)
    readonly property color titleHotColor: gold
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: ivoryA(0.55)
    readonly property string hintText: "wander · choose · wake"
    readonly property string emptyText: "nothing stirs in the meadow"

    // ── backdrop: moss vignette + fairy ring + loosed petals ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the theme's legibility trick over bright video: darken the far
            // field and pool a little dusk under the center tile
            Canvas {
                id: vignette
                anchors.fill: parent
                opacity: 0.95 * chrome.overview.reveal
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections { target: chrome.pal; function onGlassChanged() { vignette.requestPaint() } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, cx = w / 2, cy = h / 2
                    if (w < 2 || h < 2) return
                    let g = ctx.createRadialGradient(cx, cy, Math.min(w, h) * 0.32, cx, cy, Math.max(w, h) * 0.74)
                    g.addColorStop(0, chrome.rgba(chrome.moss, 0))
                    g.addColorStop(1, chrome.rgba(chrome.moss, 0.62))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                    g = ctx.createRadialGradient(cx, cy, 0, cx, cy, Math.max(60, chrome.overview.ringRadius * 0.85))
                    g.addColorStop(0, chrome.rgba(chrome.moss, 0.38))
                    g.addColorStop(1, chrome.rgba(chrome.moss, 0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                }
            }

            // fairy ring through the tile orbit — dashed sage with a few
            // buttercups resting on it. painted once; the reveal and the very
            // slow wheel are gpu transforms, not repaints
            Item {
                anchors.centerIn: parent
                width: chrome.overview.ringRadius * 2 + Math.round(40 * chrome.ui)
                height: width
                scale: Math.max(0.01, chrome.overview.reveal); opacity: 0.8 * chrome.overview.reveal
                Canvas {
                    id: ring
                    anchors.fill: parent
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    Connections {
                        target: chrome.pal
                        function onCyanChanged() { ring.requestPaint() }
                        function onDimChanged() { ring.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width < 20) return
                        const c = width / 2, r = chrome.overview.ringRadius
                        ctx.strokeStyle = Qt.lighter(chrome.pal.dim, 1.5)
                        ctx.globalAlpha = 0.28
                        ctx.lineWidth = 1
                        const segs = 40
                        for (let s = 0; s < segs; s++) {
                            const a0 = s * 2 * Math.PI / segs
                            ctx.beginPath()
                            ctx.arc(c, c, r, a0, a0 + 0.55 * 2 * Math.PI / segs)
                            ctx.stroke()
                        }
                        ctx.fillStyle = chrome.gold
                        ctx.globalAlpha = 0.5
                        for (const a of [0.5, 1.9, 3.1, 4.4, 5.6]) {
                            ctx.beginPath()
                            ctx.arc(c + Math.cos(a) * r, c + Math.sin(a) * r, 2.2 * chrome.ui, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }
                    RotationAnimation on rotation {
                        running: chrome.overview.open; loops: Animation.Infinite
                        from: 0; to: 360; duration: 180000
                    }
                }
            }

            // petals loosed over the field — one small scatter as the ring
            // fans out, then a slow trickle from above. ~20 live, tops
            ParticleSystem { id: sys; paused: !chrome.overview.open }
            Emitter {
                id: scatter
                system: sys
                anchors.fill: parent
                enabled: false           // burst-only: the reveal flourish
                lifeSpan: 20000
                velocity: AngleDirection { angle: 90; magnitude: 14; angleVariation: 12; magnitudeVariation: 8 }
            }
            Emitter {
                system: sys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; emitRate: 0.6; lifeSpan: 22000
                velocity: AngleDirection { angle: 90; magnitude: 42; angleVariation: 10; magnitudeVariation: 16 }
            }
            Wander { system: sys; xVariance: 70; pace: 30 }
            ItemParticle {
                system: sys
                delegate: Rectangle {
                    width: (6 + Math.random() * 3) * chrome.ui
                    height: width * 0.68
                    radius: height / 2
                    color: Math.random() < 0.6 ? Qt.alpha(chrome.gold, 0.5) : Qt.alpha(chrome.ivory, 0.38)
                    property real r0: Math.random() * 360
                    rotation: r0
                    NumberAnimation on rotation {
                        from: r0; to: r0 + (Math.random() < 0.5 ? 360 : -360)
                        duration: 12000 + Math.random() * 8000
                        loops: Animation.Infinite; running: chrome.overview.open
                    }
                }
            }
            // wait a beat so the loader has sized us before scattering
            Timer { interval: 60; running: true; onTriggered: scatter.burst(7) }
        }
    }

    // ── under the card: a gentle gold glow ring on the chosen tile ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: halo
            property var tile: null   // injected by the shell after load
            readonly property bool hot: tile ? tile.hot === true : false

            Item {
                anchors.fill: parent
                opacity: halo.hot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 240 } }

                // wide soft ring that breathes, barely
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(-7 * chrome.ui)
                    radius: chrome.cardRadius + Math.round(7 * chrome.ui)
                    color: "transparent"
                    border.color: chrome.goldA(0.22)
                    border.width: Math.max(2, Math.round(6 * chrome.ui))
                    SequentialAnimation on opacity {
                        running: halo.hot && chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.6; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
                    }
                }
                // and a crisp gold hairline just off the card edge
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(-3 * chrome.ui)
                    radius: chrome.cardRadius + Math.round(3 * chrome.ui)
                    color: "transparent"
                    border.color: chrome.goldA(0.38)
                    border.width: 1
                }
            }
        }
    }

    // ── over the card: a gold blossom crowning the focused window ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool ctr: tile ? tile.isCenter === true : false

            Canvas {
                id: crown
                visible: ov.ctr
                width: Math.round(30 * chrome.ui)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(7 * chrome.ui)
                Component.onCompleted: requestPaint()
                onWidthChanged: requestPaint()
                Connections { target: chrome.pal; function onCyanChanged() { crown.requestPaint() } }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width < 8) return
                    const c = width / 2, pr = width * 0.30
                    // five-petal buttercup, same hand as the notif stem head
                    ctx.strokeStyle = chrome.gold
                    ctx.globalAlpha = 0.9
                    ctx.lineWidth = 1.2
                    for (let i = 0; i < 5; i++) {
                        const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                        ctx.save()
                        ctx.translate(c + Math.cos(a) * pr * 0.75, c + Math.sin(a) * pr * 0.75)
                        ctx.rotate(a + Math.PI / 2)
                        ctx.scale(pr * 0.38, pr * 0.62)
                        ctx.beginPath()
                        ctx.arc(0, 0, 1, 0, Math.PI * 2)
                        ctx.restore()
                        ctx.stroke()
                    }
                    ctx.fillStyle = chrome.gold
                    ctx.beginPath()
                    ctx.arc(c, c, pr * 0.22, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
            // laurel hairlines flanking the blossom
            Rectangle {
                visible: ov.ctr
                width: Math.round(16 * chrome.ui); height: 1
                color: chrome.goldA(0.45)
                anchors.right: crown.left; anchors.rightMargin: 6
                anchors.verticalCenter: crown.verticalCenter
            }
            Rectangle {
                visible: ov.ctr
                width: Math.round(16 * chrome.ui); height: 1
                color: chrome.goldA(0.45)
                anchors.left: crown.right; anchors.leftMargin: 6
                anchors.verticalCenter: crown.verticalCenter
            }
        }
    }
}
