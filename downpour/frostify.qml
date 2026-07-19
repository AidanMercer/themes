import QtQuick

// downpour: music on the rain-side of the glass. The player's window is a
// pane of the same storm — condensation beads swell and dry across it while
// a song plays (fog shader, clock parked at silence or when you look away),
// a sagging sill with hanging beads sits above the bottom edge, and every
// track change spends one droplet: a bead breaks off the sill and runs.
// Chrome + voice only; the layout stays frostify's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color paneLight: pal.neon
    readonly property color skinLight: pal.cyan
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function rnd(n) {
        let x = Math.imul((n + 53) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: a soft breath-mark frame, no hard chrome
    readonly property color cardBorder: inkA(0.14)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 18

    // the pane's voice
    readonly property string statusPlaying: "▶ still raining"
    readonly property string statusPaused: "❚❚ held breath"
    readonly property string statusStopped: "■ just the rain"
    readonly property string wordmark: "◦ downpour"
    readonly property string glyphPrev: "«"
    readonly property string glyphPlay: "▶"
    readonly property string glyphPause: "❚❚"
    readonly property string glyphNext: "»"
    readonly property string glyphNowPlaying: "◦"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "·"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the condensation field — beads swell and dry over minutes,
            // only while music actually plays in a focused window
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                property real time: 0
                property real density: 0.16
                property color tint: chrome.paneLight
                opacity: 0.8
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake
                }
            }

            // the sill: a sagging hairline with beads hanging beneath it
            Canvas {
                id: sill
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 30
                height: 16
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(0, 3)
                    const seg = w / 5
                    let px = 0, py = 3
                    for (let k = 1; k <= 5; k++) {
                        const ny = 2 + 3 * chrome.rnd(k * 13 + 2)
                        ctx.quadraticCurveTo(px + seg * 0.5, py + 2.4, k * seg, ny)
                        px = k * seg; py = ny
                    }
                    ctx.strokeStyle = String(chrome.paneA(0.26))
                    ctx.lineWidth = 1.1
                    ctx.stroke()
                    for (let i = 0; i < 7; i++) {
                        const bx = w * (0.06 + 0.14 * i + 0.05 * chrome.rnd(i * 43 + 11))
                        const bs = 2.2 + 2.6 * chrome.rnd(i * 7 + 2)
                        ctx.beginPath()
                        ctx.ellipse(bx, 5, bs, bs * 1.3)
                        ctx.fillStyle = String(chrome.paneA(0.30))
                        ctx.fill()
                    }
                }
            }

            // ── every track change spends one droplet off the sill ──────────
            Item {
                id: run
                property real t: -1
                property real fx: 0.5
                visible: t >= 0
                x: bd.width * fx
                y: bd.height - 40
                Rectangle {
                    id: runBead
                    x: -2.6
                    y: 26 * Math.max(0, run.t) * Math.max(0, run.t)
                    width: 5.2; height: 6.6
                    radius: 2.6
                    color: chrome.paneA(0.9 * (1 - Math.max(0, run.t) * 0.5))
                    Rectangle { x: 1; y: 1.2; width: 1.6; height: 1.6; radius: 0.8; color: chrome.inkA(0.85) }
                }
                Rectangle {
                    x: -1.4; y: 0
                    width: 1.4
                    height: runBead.y
                    opacity: 0.4 * (1 - Math.max(0, run.t))
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: chrome.paneA(0.0) }
                        GradientStop { position: 1.0; color: chrome.paneA(0.8) }
                    }
                }
                SequentialAnimation {
                    id: runAnim
                    NumberAnimation { target: run; property: "t"; from: 0; to: 1; duration: 620 }
                    PauseAnimation { duration: 240 }
                    PropertyAction { target: run; property: "t"; value: -1 }
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() {
                    if (!chrome.awake) return
                    run.fx = 0.15 + 0.7 * chrome.rnd(Date.now() % 9973)
                    runAnim.restart()
                }
            }
        }
    }
}
