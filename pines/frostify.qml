import QtQuick

// pines: frostify is the station's WIRELESS SET. The chassis is the house
// survey grammar — a benchmark triangle and a ticked bearing rule inked
// along the head of the pane, lamp-warm ticks on the far corner — and while
// music is actually being received, fog drifts across the cab glass behind
// the panes (fog.frag). A track change is a new signal: the set exhales one
// breath of condensation onto the glass and it clears. Station voice in the
// status pill and sidebar.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // frostify window — np, npTrackId, active

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true
    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    // station voice
    readonly property string statusPlaying: "▶ RECEIVING"
    readonly property string statusPaused: "⏸ STANDING BY"
    readonly property string statusStopped: "■ AIR SILENT"
    readonly property string wordmark: "▵ PINES W/T"
    readonly property string glyphPrev: "‹"
    readonly property string glyphNext: "›"
    readonly property string glyphNowPlaying: "▸"
    readonly property string glyphPinned: "▵"
    readonly property string glyphRecent: "◔"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    // ── chassis: benchmark + bearing rule + lamp ticks ─────────────────────
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
                    // the benchmark, top-left
                    ctx.strokeStyle = chrome.pal.cyan
                    ctx.globalAlpha = 0.6
                    ctx.lineWidth = 1.2
                    ctx.beginPath()
                    ctx.moveTo(inset + 5, inset)
                    ctx.lineTo(inset + 10, inset + 8)
                    ctx.lineTo(inset, inset + 8)
                    ctx.closePath()
                    ctx.stroke()
                    // the bearing rule running from it
                    ctx.globalAlpha = 0.35
                    ctx.beginPath()
                    ctx.moveTo(inset + 18, inset + 4); ctx.lineTo(w * 0.4, inset + 4)
                    ctx.lineWidth = 1
                    ctx.stroke()
                    for (let i = 1; i <= 5; i++) {
                        const x = inset + 18 + (w * 0.4 - inset - 18) * i / 6
                        ctx.beginPath()
                        ctx.moveTo(x, inset + (i % 2 ? 2 : 0.5)); ctx.lineTo(x, inset + 4)
                        ctx.stroke()
                    }
                    // lamp-warm corner ticks, bottom-right
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.globalAlpha = 0.55
                    ctx.lineWidth = 1.4
                    ctx.beginPath()
                    ctx.moveTo(w - inset, h - inset - 14); ctx.lineTo(w - inset, h - inset)
                    ctx.lineTo(w - inset - 14, h - inset)
                    ctx.stroke()
                }
            }

            // fog drifting on the glass while the set receives
            ShaderEffect {
                anchors.fill: parent
                property real time: 0
                property real burst: 0
                property real ember: 0
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                opacity: 0.8
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake
                }
            }
        }
    }

    // ── the breath: a track change fogs the glass for a moment ─────────────
    readonly property Component overlay: Component {
        ShaderEffect {
            id: breath
            property real time: 0
            property real burst: 0
            property real ember: 0
            fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
            visible: burst > 0.01   // transient by design
            NumberAnimation {
                id: breathAnim
                target: breath; property: "burst"
                from: 1; to: 0; duration: 900
                easing.type: Easing.OutQuad
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.host.npTrackId) breathAnim.restart() }
            }
        }
    }
}
