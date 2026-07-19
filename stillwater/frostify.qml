import QtQuick

// stillwater: music carried across the water. The player window gets the
// theme's fullest shore: a waterline banked along the bottom with a town's
// worth of lamps standing on it, every one doubled beneath as a broken
// streak, and dusk-rose pooling above the line. While music actually plays
// in a focused window the shore is alive — three lamps breathe in slow
// rounds and their streaks stretch and settle; pause, and the water holds
// still mid-evening. On every track change a light crosses the whole shore
// and one ripple blooms where it lands. Chrome + voice only; the layout
// stays frostify's own.
Item {
    id: chrome

    required property var pal   // snapshot palette (lamp/twilight/rose…)
    property var host: null     // frostify window — active (focus), np, npTrackId

    readonly property bool awake: host ? host.active === true : false
    readonly property bool playing: host && host.np
                                    && host.np.active === true && host.np.isPlaying === true

    readonly property color lamp: pal.neon
    readonly property color sky: pal.cyan
    readonly property color rose: pal.magenta
    function lampA(a) { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function skyA(a)  { return Qt.rgba(sky.r, sky.g, sky.b, a) }
    function roseA(a) { return Qt.rgba(rose.r, rose.g, rose.b, a) }

    // deterministic hash — the same shore on every mount (its own seed, so
    // the radio faces a different stretch of coast than mica)
    function rnd(n) {
        let x = Math.imul((n + 101) ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // chassis: soft water glass, a thin twilight lip
    readonly property color cardBorder: Qt.alpha(sky, 0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 10

    // the mirror's voice
    readonly property string statusPlaying: "◦ carried across the water"
    readonly property string statusPaused: "◦ held still"
    readonly property string statusStopped: "◦ the water sleeps"
    readonly property string wordmark: "◦ stillwater"
    readonly property string glyphPrev: "◁◁"
    readonly property string glyphPlay: "▷"
    readonly property string glyphPause: "▮▮"
    readonly property string glyphNext: "▷▷"
    readonly property string glyphNowPlaying: "◦"
    readonly property string glyphLiked: "♥"
    readonly property string glyphPinned: "▪"
    readonly property string glyphRecent: "↺"
    readonly property string glyphDesktop: "⌂"
    readonly property string glyphPlaylist: "≡"

    readonly property Component backdrop: Component {
        Item {
            id: bd

            readonly property real wl: height - 58

            // dusk pooling above the line
            Rectangle {
                x: 0; y: bd.wl - 70
                width: parent.width
                height: 70
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.roseA(0.06) }
                }
            }
            // the water holds the light below
            Rectangle {
                x: 0; y: bd.wl
                width: parent.width
                height: parent.height - bd.wl
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle { x: 0; y: bd.wl; width: parent.width; height: 1; color: chrome.skyA(0.26) }

            // ── the shore, one static draw ─────────────────────────────────
            Canvas {
                id: shore
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()   // wl rides height
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const wl = bd.wl, W = width
                    const n = Math.max(6, Math.floor(W / 90))
                    for (let i = 0; i < n; i++) {
                        const fx = 0.03 + chrome.rnd(i * 17 + 3) * 0.94
                        const lv = 0.3 + chrome.rnd(i * 29 + 7) * 0.6
                        const cx = Math.round(W * fx)
                        const s = chrome.rnd(i * 41 + 11)
                        const tone = s < 0.12 ? chrome.rose : s < 0.24 ? chrome.sky : chrome.lamp
                        ctx.fillStyle = String(Qt.rgba(tone.r, tone.g, tone.b, 0.25 + 0.5 * lv))
                        ctx.fillRect(cx - 1.5, wl - 3, 3, 3)
                        let y = wl + 4, k = 0
                        while (y < wl + 5 + lv * 26 && y < height - 3) {
                            const depth = (y - wl) / 34
                            ctx.fillStyle = String(Qt.rgba(tone.r, tone.g, tone.b, lv * 0.38 * (1 - depth)))
                            ctx.fillRect(cx - 1, y, 2, 2)
                            y += 4 + k * 2
                            k++
                        }
                    }
                }
            }

            // three lamps breathe in rounds while the music actually plays —
            // their streaks stretch and settle like light on moving water
            Repeater {
                model: 3
                Item {
                    id: liveLamp
                    required property int index
                    x: Math.round(bd.width * (0.18 + index * 0.3))
                    y: bd.wl
                    property real breath: 0.4
                    SequentialAnimation on breath {
                        running: chrome.playing && chrome.awake && bd.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.0; duration: 1800 + liveLamp.index * 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.25; duration: 1800 + liveLamp.index * 600; easing.type: Easing.InOutSine }
                    }
                    Rectangle {
                        x: -2; y: -3
                        width: 4; height: 4
                        radius: 2
                        color: chrome.lampA(0.3 + 0.6 * liveLamp.breath)
                    }
                    Rectangle {
                        x: -1; y: 3
                        width: 2
                        height: 3 + 10 * liveLamp.breath
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: chrome.lampA(0.4) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }
            }

            // ── a track change: a light crosses the whole shore ────────────
            Item {
                id: ferry
                property real t: -1
                visible: t >= 0
                y: bd.wl
                x: bd.width * Math.max(0, t) - 10
                Rectangle { x: -2; y: -3; width: 4; height: 4; radius: 2; color: chrome.lamp }
                Rectangle { x: -18; y: -1; width: 16; height: 1; color: chrome.lampA(0.25) }
                Rectangle { x: -1; y: 3; width: 2; height: 2; color: chrome.lampA(0.35) }
                NumberAnimation {
                    id: ferryAnim
                    target: ferry; property: "t"
                    from: 0; to: 1; duration: 1500; easing.type: Easing.InOutSine
                }
            }
            // …and one ripple blooms where it lands
            Item {
                id: landing
                x: Math.round(bd.width * 0.86)
                y: bd.wl
                property real t: -1
                visible: t >= 0
                Rectangle {
                    anchors.centerIn: parent
                    width: 6 + 90 * Math.max(0, landing.t)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: chrome.lampA(0.45 * (1 - Math.max(0, landing.t)))
                    transform: Scale { origin.y: (6 + 90 * Math.max(0, landing.t)) / 2; yScale: 0.2 }
                }
                NumberAnimation {
                    id: landingAnim
                    target: landing; property: "t"
                    from: 0; to: 1; duration: 1300; easing.type: Easing.OutSine
                    onStopped: landing.t = -1
                }
            }
            SequentialAnimation {
                id: crossing
                ScriptAction { script: ferryAnim.restart() }
                PauseAnimation { duration: 1500 }
                ScriptAction { script: { ferry.t = -1; landingAnim.restart() } }
            }
            Connections {
                target: chrome.host
                enabled: chrome.host !== null
                function onNpTrackIdChanged() { if (chrome.awake) crossing.restart() }
            }
        }
    }
}
