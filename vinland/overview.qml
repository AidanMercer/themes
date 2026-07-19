import QtQuick
import QtQuick.Particles

// vinland: the Super+Tab exposé as a night voyage chart — the fleet at sea.
// Every open window is a sail on the water; stitched course lines run from
// where thorfinn stands (dead center, the flagship) out to each ship's real
// position, sewn like routes on a sea chart. A compass rose sits low in the
// corner and its gold needle swings to the bearing of whichever sail the
// helm picks; that ship's course brightens ice and a gold north star glints
// at its masthead. The aurora breathes across the top of the sky, snow
// drifts through the whole scene, and a cap of snow lies settled on every
// card — things left out in the cold gather it. The shell keeps layout /
// thumbnails / nav; this file only dresses the crossing.
//
// visual-only by contract — no input handlers anywhere; every looping
// animation gates on overview.open (the shell tears these layers down
// ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=ice cyan=gold magenta=rose dim=slate
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color night: pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    function snowA(a)  { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)   { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function nightA(a) { return Qt.rgba(night.r, night.g, night.b, a) }

    // ── scalars: deep-night scrim, night-glass sails with an ice hairline ──
    readonly property color scrimColor: Qt.darker(night, 1.7)
    readonly property real scrimOpacity: 0.66
    readonly property bool shadowOn: true
    readonly property color shadowColor: {
        const c = Qt.darker(night, 2.2)
        return Qt.rgba(c.r, c.g, c.b, 0.6)
    }
    readonly property color cardBg: nightA(0.92)
    readonly property color cardBorder: iceA(0.26)
    readonly property color cardBorderHot: gold            // the one warm color
    readonly property color cardBorderCenter: iceA(0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 10
    readonly property color cardHighlight: snowA(0.08)     // starlight on the glass
    readonly property color thumbBg: Qt.darker(night, 1.4)
    readonly property int thumbRadius: 7
    readonly property color titleColor: snowA(0.62)
    readonly property color titleHotColor: gold
    readonly property string titleFont: "Noto Sans"
    readonly property string hintFont: serif
    readonly property color hintColor: iceA(0.55)
    readonly property string hintText: "steer with the arrows · enter to board · esc turns for home"
    readonly property string emptyText: "no sails on the horizon"

    // bearing of the picked sail, 0° = due north (screen-up)
    readonly property real bearingDeg: {
        const ts = overview.tiles
        const i = overview.selected
        if (i < 0 || i >= ts.length) return 0
        const t = ts[i]
        if (t.center) return 0
        return Math.atan2(t.ry, t.rx) * 180 / Math.PI + 90
    }

    // ── backdrop: aurora sky, sewn course lines, compass rose, far snow ──
    readonly property Component backdrop: Component {
        Item {
            // the aurora, breathing across the top of the sky
            ShaderEffect {
                anchors.fill: parent
                opacity: 0.85 * chrome.overview.reveal
                fragmentShader: Qt.resolvedUrl("aurora.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.overview.open
                }
            }

            // frost mist pooled along the foot of the water
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.round(parent.height * 0.18)
                opacity: chrome.overview.reveal
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.iceA(0.08) }
                }
            }

            // the chart: course lines sewn from the flagship out to each
            // sail's live position — stitch by stitch, like thread on vellum.
            // The picked sail's course pulls bright ice; the rest stay faint.
            // A stitched ring runs through the fleet's orbit.
            Canvas {
                id: chart
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.overview
                    function onRevealChanged() { chart.requestPaint() }
                    function onTilesChanged() { chart.requestPaint() }
                    function onSelectedChanged() { chart.requestPaint() }
                }
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { chart.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2
                    const rv = chrome.overview.reveal
                    const ts = chrome.overview.tiles
                    ctx.lineCap = "round"

                    // sewn course lines (Canvas has no setLineDash — stitch by hand)
                    const stitch = 7, gap = 6
                    for (let i = 0; i < ts.length; i++) {
                        if (ts[i].center) continue
                        const hot = i === chrome.overview.selected
                        const tx = cx + ts[i].rx * rv
                        const ty = cy + ts[i].ry * rv
                        const dx = tx - cx, dy = ty - cy
                        const len = Math.sqrt(dx * dx + dy * dy)
                        if (len < 70) continue
                        const ux = dx / len, uy = dy / len
                        ctx.strokeStyle = chrome.ice
                        ctx.globalAlpha = hot ? 0.5 : 0.13
                        ctx.lineWidth = hot ? 1.5 : 1
                        // start clear of the flagship, stop short of the sail
                        for (let d = 58; d < len - 26; d += stitch + gap) {
                            const e = Math.min(d + stitch, len - 26)
                            ctx.beginPath()
                            ctx.moveTo(cx + ux * d, cy + uy * d)
                            ctx.lineTo(cx + ux * e, cy + uy * e)
                            ctx.stroke()
                        }
                    }

                    // the fleet's orbit, sewn the same way
                    const R = chrome.overview.ringRadius * rv
                    if (R > 20) {
                        ctx.strokeStyle = chrome.ice
                        ctx.globalAlpha = 0.09
                        ctx.lineWidth = 1
                        const step = (stitch + gap) / R
                        const arc = stitch / R
                        for (let a = 0; a < 2 * Math.PI - arc; a += step) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, R, a, a + arc)
                            ctx.stroke()
                        }
                    }
                }
            }

            // the compass rose, low in the corner of the chart — a notched
            // bearing ring around a thin four-point star, north pricked gold
            Item {
                id: rose
                x: Math.round(44 * chrome.ui)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(64 * chrome.ui)
                width: Math.round(84 * chrome.ui)
                height: width
                opacity: 0.85 * chrome.overview.reveal

                Canvas {
                    id: roseFace
                    anchors.fill: parent
                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    Connections {
                        target: chrome.pal
                        function onNeonChanged() { roseFace.requestPaint() }
                        function onCyanChanged() { roseFace.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (width < 20) return
                        const c = width / 2, R = width / 2 - 3
                        ctx.strokeStyle = chrome.iceA(0.30)
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.arc(c, c, R, 0, Math.PI * 2)
                        ctx.stroke()
                        // eight bearing notches, cardinals cut deeper
                        for (let i = 0; i < 8; i++) {
                            const a = i * Math.PI / 4
                            const r1 = i % 2 === 0 ? R - 6 : R - 3.5
                            ctx.beginPath()
                            ctx.moveTo(c + Math.cos(a) * r1, c + Math.sin(a) * r1)
                            ctx.lineTo(c + Math.cos(a) * R, c + Math.sin(a) * R)
                            ctx.stroke()
                        }
                        // the four-point star at the heart
                        const sR = R * 0.56
                        ctx.strokeStyle = chrome.iceA(0.34)
                        ctx.beginPath()
                        ctx.moveTo(c, c - sR)
                        ctx.quadraticCurveTo(c, c, c + sR, c)
                        ctx.quadraticCurveTo(c, c, c, c + sR)
                        ctx.quadraticCurveTo(c, c, c - sR, c)
                        ctx.quadraticCurveTo(c, c, c, c - sR)
                        ctx.closePath()
                        ctx.stroke()
                        // north is the gold prick
                        ctx.fillStyle = chrome.goldA(0.9)
                        ctx.beginPath()
                        ctx.arc(c, c - R, 1.8, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }

                // the needle — swings to the bearing of the picked sail,
                // settles back to north when the helm lets go
                Item {
                    anchors.fill: parent
                    rotation: chrome.bearingDeg
                    Behavior on rotation {
                        RotationAnimation {
                            direction: RotationAnimation.Shortest
                            duration: 480
                            easing.type: Easing.OutBack
                        }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.round(10 * chrome.ui)
                        width: 1.5
                        height: parent.height / 2 - y
                        color: chrome.goldA(0.85)
                        antialiasing: true
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 8
                    text: "westward"
                    font.family: chrome.serif
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.italic: true
                    font.letterSpacing: 3
                    color: chrome.snowA(0.35)
                }
            }

            // ── the watch's log, top corners ──
            Row {
                x: Math.round(46 * chrome.ui)
                y: Math.round(40 * chrome.ui)
                spacing: 10
                opacity: chrome.overview.reveal

                Canvas {
                    id: pip
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(10 * chrome.ui); height: width
                    Component.onCompleted: requestPaint()
                    Connections {
                        target: chrome.pal
                        function onCyanChanged() { pip.requestPaint() }
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const c = width / 2, R = width / 2
                        ctx.beginPath()
                        ctx.moveTo(c, c - R)
                        ctx.quadraticCurveTo(c, c, c + R, c)
                        ctx.quadraticCurveTo(c, c, c, c + R)
                        ctx.quadraticCurveTo(c, c, c - R, c)
                        ctx.quadraticCurveTo(c, c, c, c - R)
                        ctx.closePath()
                        ctx.fillStyle = chrome.goldA(0.95)
                        ctx.fill()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "the fleet"
                    font.family: chrome.serif
                    font.pixelSize: Math.round(15 * chrome.ui)
                    font.italic: true
                    font.weight: Font.Medium
                    font.letterSpacing: 6
                    color: chrome.snow
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ᚠᛚᛟᛏᛁ"
                    font.family: "Noto Sans Runic"
                    font.pixelSize: Math.round(11 * chrome.ui)
                    font.letterSpacing: 4
                    color: chrome.iceA(0.45)
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(46 * chrome.ui)
                y: Math.round(44 * chrome.ui)
                text: {
                    const n = chrome.overview.windows.length
                    // the shell's emptyText already covers a bare horizon
                    return n === 0 ? ""
                         : n === 1 ? "one sail on the water"
                                   : n + " sails on the water"
                }
                font.family: chrome.serif
                font.pixelSize: Math.round(11 * chrome.ui)
                font.italic: true
                font.letterSpacing: 2
                color: chrome.snowA(0.45)
                opacity: chrome.overview.reveal
            }

            // far snow, half-lost against the night
            ParticleSystem {
                id: farSys
                running: true
                paused: !chrome.overview.open
            }
            Emitter {
                system: farSys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 1.6
                lifeSpan: 16000
                velocity: AngleDirection {
                    angle: 90; magnitude: 26
                    angleVariation: 6; magnitudeVariation: 10
                }
            }
            Wander { system: farSys; xVariance: 45; pace: 30 }
            ItemParticle {
                system: farSys
                delegate: Rectangle {
                    width: 2 * chrome.ui; height: width; radius: width / 2
                    color: chrome.snowA(0.16 + Math.random() * 0.16)
                }
            }
        }
    }

    // ── per-tile, behind the card: frost breath — a ring of ice light
    // that gathers around the picked sail ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load
            readonly property bool lit: ur.tile ? ur.tile.hot === true : false

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + Math.round(26 * chrome.ui)
                height: parent.height + Math.round(26 * chrome.ui)
                radius: chrome.cardRadius + Math.round(13 * chrome.ui)
                color: "transparent"
                border.width: Math.round(13 * chrome.ui)
                border.color: chrome.iceA(0.10)
                opacity: ur.lit ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
        }
    }

    // ── per-tile, above the card: settled snow on the top edge, the gold
    // north star glinting at the picked sail's masthead, and the flagship's
    // quiet "at the helm" tag ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool lit: ov.tile ? ov.tile.hot === true : false
            readonly property bool ctr: ov.tile ? ov.tile.isCenter === true : false
            readonly property int idx: ov.tile ? ov.tile.index : 0

            onLitChanged: if (lit) glint.restart()

            // snow settled along the top of the card — each sail carries a
            // slightly different drift
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -1
                width: parent.width * (0.62 + (ov.idx % 3) * 0.11)
                height: Math.max(2, Math.round(2.5 * chrome.ui))
                radius: height / 2
                color: chrome.snowA(0.30 + (ov.idx % 2) * 0.08)
            }

            // the north star at the masthead of the picked sail
            Canvas {
                id: mast
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -Math.round(6 * chrome.ui)
                anchors.topMargin: -Math.round(7 * chrome.ui)
                width: Math.round(15 * chrome.ui); height: width
                opacity: ov.lit ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onCyanChanged() { mast.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2, R = width / 2
                    ctx.beginPath()
                    ctx.moveTo(c, c - R)
                    ctx.quadraticCurveTo(c, c, c + R, c)
                    ctx.quadraticCurveTo(c, c, c, c + R)
                    ctx.quadraticCurveTo(c, c, c - R, c)
                    ctx.quadraticCurveTo(c, c, c, c - R)
                    ctx.closePath()
                    ctx.fillStyle = chrome.goldA(0.95)
                    ctx.fill()
                }
                SequentialAnimation {
                    id: glint
                    running: false
                    NumberAnimation { target: mast; property: "scale"; from: 0.4; to: 1.3; duration: 160; easing.type: Easing.OutQuad }
                    NumberAnimation { target: mast; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.InOutQuad }
                }
            }

            // the flagship — where thorfinn already stands
            Row {
                visible: ov.ctr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(8 * chrome.ui)
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4; height: 4
                    rotation: 45
                    color: chrome.goldA(0.85)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "at the helm"
                    font.family: chrome.serif
                    font.pixelSize: Math.round(10 * chrome.ui)
                    font.italic: true
                    font.letterSpacing: 3
                    color: chrome.snowA(0.55)
                }
            }
        }
    }

    // ── overlay: a breath of near snow drifting over the whole fleet ──
    readonly property Component overlay: Component {
        Item {
            ParticleSystem {
                id: nearSys
                running: true
                paused: !chrome.overview.open
            }
            Emitter {
                system: nearSys
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                emitRate: 0.7
                lifeSpan: 12000
                velocity: AngleDirection {
                    angle: 90; magnitude: 46
                    angleVariation: 8; magnitudeVariation: 14
                }
            }
            Wander { system: nearSys; xVariance: 55; pace: 40 }
            ItemParticle {
                system: nearSys
                delegate: Rectangle {
                    width: (3 + Math.random()) * chrome.ui
                    height: width; radius: width / 2
                    color: chrome.snowA(0.22 + Math.random() * 0.18)
                }
            }
        }
    }
}
