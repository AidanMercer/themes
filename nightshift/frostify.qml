import QtQuick
import "windows.js" as W

// nightshift: chrome for the frostify Spotify app. Someone playing music at
// this hour is one of the windows still lit — so the block behind the panes
// burns while the track runs and empties when it stops, and a track change
// sends the sodium surge through the haze and relights the whole facade.
//
// Effects, chrome and voice only — the layout stays frostify's own.
Item {
    id: chrome

    // injected by frostify's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : true
    readonly property bool playing: host && host.np ? host.np.isPlaying === true : false
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    // glass, not a wall — the block across the street reads through the frame
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.40)
    readonly property color cardBorder: hazeA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3

    // ── voice ───────────────────────────────────────────────────────────────
    readonly property string wordmark: "▶ still up"
    readonly property string statusPlaying: "playing"
    readonly property string statusPaused: "held"
    readonly property string statusStopped: "dark"
    readonly property string glyphPrev: "◄"
    readonly property string glyphPlay: "▶"
    readonly property string glyphPause: "■"
    readonly property string glyphNext: "►"
    readonly property string glyphNowPlaying: "▪"
    readonly property string glyphLiked: "◆"
    readonly property string glyphPinned: "▪"
    readonly property string glyphRecent: "◷"
    readonly property string glyphDesktop: "▦"
    readonly property string glyphPlaylist: "▤"

    // ── the surge, fired on a track change ──────────────────────────────────
    property real warm: 0
    property int trackSeed: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 1; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 1700; easing.type: Easing.InOutSine }
    }
    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        // npTrackId is the stable id — np itself churns on every progress tick
        function onNpTrackIdChanged() {
            chrome.trackSeed++
            if (chrome.awake) surge.restart()
        }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: chrome.warm
                property real density: 0.6
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g,
                                                       chrome.pal.neon.b, 1)
                opacity: 0.36          // haze, not paint — the frame stays glass
                // the air moves while the window is up AND something is playing
                NumberAnimation on time {
                    running: chrome.awake && chrome.playing
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                }
            }

            // the block across the street: more of it is awake while music runs
            Facade {
                anchors.fill: parent
                anchors.margins: -6
                cols: Math.max(7, Math.floor(parent.width / 30))
                rows: Math.max(6, Math.floor(parent.height / 30))
                cell: 13
                gap: 8
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.07
                dim: (chrome.playing ? 0.34 : 0.16) + 0.30 * chrome.warm
                flicker: chrome.awake
                spread: 900
                opacity: 0.62
                plan: {
                    const c = Math.max(7, Math.floor(parent.width / 30))
                    const r = Math.max(6, Math.floor(parent.height / 30))
                    const p = W.blank(c, r)
                    const seed = (chrome.trackSeed + 1) * 6151
                    const fill = chrome.playing ? 0.22 : 0.09
                    for (let i = 0; i < p.length; i++)
                        if ((((i + 1) * 2654435761 + seed) % 1013) / 1013 < fill) p[i] = 1
                    return p
                }
            }
        }
    }
}
