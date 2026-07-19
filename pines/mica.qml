import QtQuick

// pines: mica is the CHART ROOM — the drawer of map sheets under the cab
// glass. The house chassis (benchmark + ticked bearing rule + lamp corner
// ticks) frames the miller columns, faint topographic contours sit inked
// into the bottom corner of the paper, and fog drifts across the glass
// while the room is in use. Every directory change is a drawer sliding
// open: the glass takes one breath of condensation and clears.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // mica window — active (focus), navId (cwd)

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    readonly property string wordmark: "▵ CHART ROOM"

    readonly property Component backdrop: Component {
        Item {
            Canvas {
                id: chassis
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, inset = 8
                    // benchmark, top-left
                    ctx.strokeStyle = chrome.pal.cyan
                    ctx.globalAlpha = 0.6
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(inset + 5, inset)
                    ctx.lineTo(inset + 10, inset + 8)
                    ctx.lineTo(inset, inset + 8)
                    ctx.closePath()
                    ctx.stroke()
                    // bearing rule under the breadcrumb row
                    ctx.globalAlpha = 0.35
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w * 0.4, inset + 4)
                    ctx.stroke()
                    for (let i = 1; i <= 5; i++) {
                        const x = inset + 18 + (w * 0.4 - inset - 18) * i / 6
                        ctx.beginPath()
                        ctx.moveTo(x, inset + (i % 2 ? 2 : 0.5)); ctx.lineTo(x, inset + 4)
                        ctx.stroke()
                    }
                    // contours in the bottom-left of the sheet
                    const cx = w * 0.10, cy = h * 0.92
                    for (let ring = 0; ring < 4; ring++) {
                        const base = 22 + ring * 20
                        ctx.beginPath()
                        for (let a = 0; a <= 48; a++) {
                            const th = a / 48 * Math.PI * 2
                            const r = base + Math.sin(th * 3 + 1.3 + ring) * base * 0.14
                            const x = cx + Math.cos(th) * r
                            const y = cy + Math.sin(th) * r * 0.8
                            if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.closePath()
                        ctx.strokeStyle = chrome.pal.dim
                        ctx.globalAlpha = 0.14 - ring * 0.025
                        ctx.stroke()
                    }
                    // lamp corner ticks, bottom-right
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                    ctx.lineTo(w - inset - 14, h - inset)
                    ctx.stroke()
                }
            }

            // fog on the glass while the room is in use
            ShaderEffect {
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                property real ember: 0
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                opacity: 0.7
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }
        }
    }

    // ── the breath: a directory change fogs the glass for a moment ─────────
    readonly property Component overlay: Component {
        ShaderEffect {
            id: breath
            property real time: 0
            property real burst: 0
            property real ember: 0
            fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
            // the shader's ambient banks don't scale with burst — dissolve the
            // whole layer over the breath's tail so nothing snaps off
            opacity: Math.min(1, burst / 0.15)
            visible: burst > 0.01   // transient by design
            NumberAnimation {
                id: breathAnim
                target: breath; property: "burst"
                from: 1; to: 0; duration: 800
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNavIdChanged() { if (chrome.awake) breathAnim.restart() }
            }
        }
    }
}
