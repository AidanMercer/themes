import QtQuick

// road8: the dash radio. The player is the head unit of a parked car — CRT
// glass over the panes (scanlines, one slow interference band, the city's
// glow breathing up from the bottom edge, all shader work gated on playback)
// and the 8-bit skyline banked along the bottom of the window, its amber
// windows burning while the music runs. On every track change another car
// passes: two taillight pixels dash the hill road above the rooftops, snapped
// to the 8px grid. Chrome + voice only; the layout stays frostify's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (amber/starlight/taillight…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function starA(a)  { return Qt.rgba(starlight.r, starlight.g, starlight.b, a) }

    // deterministic hash — the same city on every mount (different seed to
    // mica's, so the radio parks on a different street)
    function rnd(n) {
        let x = Math.imul((n + 101) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: pixel hardware — a thin amber lip, corners barely rounded
    readonly property color cardBorder: Qt.alpha(amber, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    // the head unit's voice
    readonly property string statusPlaying: "▶ ON AIR"
    readonly property string statusPaused: "▮▮ PULLED OVER"
    readonly property string statusStopped: "■ ENGINE OFF"
    readonly property string wordmark: "♪ DASH RADIO"
    readonly property string glyphPrev: "◀◀"
    readonly property string glyphPlay: "▶"
    readonly property string glyphPause: "▮▮"
    readonly property string glyphNext: "▶▶"
    readonly property string glyphNowPlaying: "▶"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "▪"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property int g: 8          // the pixel grid
            readonly property int band: 60      // skyline height

            // CRT glass: scanlines + interference + breathing glow. the clock
            // only runs while music actually plays in a focused window.
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("crt.frag.qsb")
                property real time: 0
                property real px: height
                property color glow: chrome.amber
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.playing && chrome.awake
                }
            }

            // ── the city along the bottom, one static draw ──────────────────
            Canvas {
                id: city
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: bd.band
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const g = bd.g, W = width, H = height
                    const cols = Math.ceil(W / g), rows = H / g
                    ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                    ctx.fillRect(0, H - 2 * g, W, 2 * g)
                    let c = 0
                    while (c < cols) {
                        const bw = 2 + Math.floor(chrome.rnd(c * 7 + 1) * 5)
                        const bh = 2 + Math.floor(chrome.rnd(c * 13 + 5) * (rows - 2))
                        ctx.fillStyle = String(Qt.alpha(chrome.pal.glass, 0.60))
                        ctx.fillRect(c * g, H - bh * g, bw * g - 2, bh * g)
                        for (let r = 0; r < bh; r++)
                            for (let k = 0; k < bw; k++) {
                                const s = chrome.rnd(c * 977 + r * 53 + k * 17)
                                if (s < 0.22) {
                                    ctx.fillStyle = s < 0.03 ? String(chrome.starA(0.45))
                                                             : String(chrome.amberA(0.5))
                                    ctx.fillRect(c * g + k * g + 2, H - bh * g + r * g + 2, 4, 4)
                                }
                            }
                        c += bw + (chrome.rnd(c * 3 + 2) < 0.3 ? 1 : 0)
                    }
                }
            }

            // a few windows flicker while the radio plays — hard on/off
            Repeater {
                model: 7
                Rectangle {
                    id: flick
                    required property int index
                    width: 4; height: 4
                    color: chrome.amberA(0.5)
                    x: Math.floor(chrome.rnd(index * 17 + 3) * (bd.width / bd.g)) * bd.g + 2
                    y: bd.height - (1 + Math.floor(chrome.rnd(index * 29 + 7) * 2)) * bd.g + 2
                    opacity: 0.8
                    SequentialAnimation on opacity {
                        running: chrome.playing && chrome.awake && bd.visible
                        loops: Animation.Infinite
                        onStopped: flick.opacity = 0.8
                        PauseAnimation { duration: 900 + chrome.rnd(flick.index * 41) * 2600 }
                        NumberAnimation { to: 0.12; duration: 0 }
                        PauseAnimation { duration: 140 + chrome.rnd(flick.index * 59) * 420 }
                        NumberAnimation { to: 0.8; duration: 0 }
                    }
                }
            }

            // ── the cassette in the deck, bottom-left above the skyline —
            // reels only turn while tape's rolling, in hard 45° steps ──
            Item {
                id: deck
                x: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bd.band + 12
                width: 46
                height: 28
                opacity: chrome.playing ? 0.9 : 0.5
                Behavior on opacity { NumberAnimation { duration: 300 } }
                property int step: 0
                Timer {
                    interval: 280; repeat: true
                    running: chrome.playing && chrome.awake && bd.visible
                    onTriggered: deck.step = (deck.step + 1) % 8
                }
                Rectangle {   // shell
                    anchors.fill: parent
                    color: Qt.alpha(chrome.pal.glass, 0.85)
                    border.width: 1
                    border.color: chrome.amberA(0.4)
                }
                Rectangle { x: 4; y: 4; width: 38; height: 5; color: chrome.amberA(0.25) }   // label
                Rectangle { x: 4; y: 4; width: 5; height: 5; color: chrome.tail }            // side A pip
                Rectangle {   // tape window
                    x: 8; y: 13; width: 30; height: 11
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.width: 1
                    border.color: Qt.alpha(chrome.pal.dim, 0.8)
                }
                Repeater {    // the reels
                    model: 2
                    Item {
                        required property int index
                        x: index === 0 ? 11 : 28
                        y: 15
                        width: 7; height: 7
                        rotation: deck.step * 45   // int steps — it clicks, never spins
                        Rectangle { x: 0; y: 2.5; width: 7; height: 2; color: chrome.amberA(0.85) }
                        Rectangle { x: 2.5; y: 0; width: 2; height: 7; color: chrome.amberA(0.85) }
                    }
                }
            }

            // the lone star, up and right
            Item {
                x: bd.width - 44
                y: 26
                opacity: 0.75
                Rectangle { x: -1; y: 3; width: 10; height: 2; color: chrome.starA(0.8) }
                Rectangle { x: 3; y: -1; width: 2; height: 10; color: chrome.starA(0.8) }
                SequentialAnimation on opacity {
                    running: chrome.awake && bd.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.75; duration: 2600; easing.type: Easing.InOutSine }
                }
            }

            // ── on every track change a car passes above the rooftops ──────
            Item {
                id: streak
                property real t: -1
                visible: t >= 0
                y: bd.height - bd.band - 13
                x: Math.round((bd.width + 40) * Math.max(0, t) / 8) * 8 - 20
                Rectangle { x: 0; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: 8; width: 5; height: 5; color: chrome.tail }
                Rectangle { x: -7; y: 1; width: 4; height: 4; color: chrome.amberA(0.35) }
                NumberAnimation {
                    id: streakAnim
                    target: streak; property: "t"
                    from: 0; to: 1; duration: 800
                    onStopped: streak.t = -1
                }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.awake) streakAnim.restart() }
            }
        }
    }
}
