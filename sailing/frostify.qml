import QtQuick

// sailing: dusk at sea behind the panes — a lavender horizon low in the frame
// and one long swell rolling through it while the music plays; the water goes
// still when it stops. A dusk burgee flies from a brass halyard top-right:
// its tail snaps once and streams back to steady each time the boat comes
// about onto a new track. Logbook voice on the status pill, harbor glyphs
// down the sidebar.
Item {
    id: chrome

    required property var pal
    property var host: null    // frostify window — np, npTrackId, active

    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true
    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.dim, 0.55)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14   // porthole-round, the popup's corner

    // logbook voice
    readonly property string statusPlaying: "▶ UNDER SAIL"
    readonly property string statusPaused: "⏸ BECALMED"
    readonly property string statusStopped: "■ ANCHORED"
    readonly property string wordmark: "⚓ adrift"
    readonly property string glyphPrev: "↞"
    readonly property string glyphNext: "↠"
    readonly property string glyphNowPlaying: "≈"
    readonly property string glyphPinned: "☸"
    readonly property string glyphRecent: "🧭"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "⛵"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the whole sea in one pass: horizon blush, rolling wave contours,
            // deep water at the hull — becalmed to a static draw when paused
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("sea.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake && bd.visible
                }
            }

            // the burgee: a dusk pennant bent onto a brass halyard, streaming
            // to leeward. Drawn once and left hanging — a track change spikes
            // `snap` and the tail whips through a travelling wave and settles.
            Canvas {
                id: pennant
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 18
                width: 74; height: 34
                property real snap: 0
                onSnapChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const s = pennant.snap
                    const hx = width - 6, hy = 9
                    const len = 52, amp = 1.2 + 6 * s, ph = (1 - s) * Math.PI * 3
                    // halyard from the deckhead
                    ctx.strokeStyle = Qt.alpha(chrome.pal.amber, 0.55)
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(hx, 0); ctx.lineTo(hx, hy + 12); ctx.stroke()
                    // the cloth: tapered, waving harder toward the free end
                    ctx.beginPath()
                    ctx.moveTo(hx, hy)
                    for (let i = 1; i <= 8; i++) {
                        const t = i / 8, half = 6 * (1 - t)
                        const wave = Math.sin(ph + t * 4.4) * amp * t
                        ctx.lineTo(hx - len * t, hy + 6 - half + wave)
                    }
                    for (let i = 8; i >= 0; i--) {
                        const t = i / 8, half = 6 * (1 - t)
                        const wave = Math.sin(ph + t * 4.4) * amp * t
                        ctx.lineTo(hx - len * t, hy + 6 + half + wave)
                    }
                    ctx.closePath()
                    ctx.fillStyle = Qt.alpha(chrome.pal.cyan, 0.5)
                    ctx.fill()
                    // the tail runs lifebuoy red
                    ctx.strokeStyle = Qt.alpha(chrome.pal.neon, 0.85)
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    for (let i = 6; i <= 8; i++) {
                        const t = i / 8
                        const y = hy + 6 + Math.sin(ph + t * 4.4) * amp * t
                        if (i === 6) ctx.moveTo(hx - len * t, y); else ctx.lineTo(hx - len * t, y)
                    }
                    ctx.stroke()
                }
                NumberAnimation {
                    id: snapAnim
                    target: pennant; property: "snap"
                    from: 1; to: 0; duration: 900
                    easing.type: Easing.OutCubic
                }
                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNpTrackIdChanged() { if (chrome.host.npTrackId) snapAnim.restart() }
                }
            }
        }
    }
}
