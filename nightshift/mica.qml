import QtQuick
import "windows.js" as W

// nightshift: chrome for the mica file manager. The miller columns are floors
// of the same building — so the backdrop is the haze over the district with a
// tall facade standing behind the columns, and every directory change sends a
// wave of sodium through the haze while a fresh scatter of rooms lights on the
// block. Navigating is somebody walking up a stairwell turning lights on.
//
// Effects and voice only — the layout stays mica's own. No input handlers.
Item {
    id: chrome

    // injected by mica's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property string sans: "Noto Sans"
    readonly property bool awake: host ? host.active === true : true
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    // glass, not a wall — the district has to be visible through the window
    // (0.40 is the frame alpha every world80 app defaults to; Hyprland's blur
    // does the rest)
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.40)
    readonly property color cardBorder: hazeA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3
    readonly property string wordmark: "◧ floors"

    // the sodium surge, shared by the haze and the facade. One-shot on nav.
    property real warm: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 1; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 1500; easing.type: Easing.InOutSine }
    }
    // a stable id that changes on every directory change — the file manager's
    // page turn. Flourish on this, not on the noisier cwd.
    property int navSeed: 0
    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        function onNavIdChanged() {
            chrome.navSeed++
            if (chrome.awake) surge.restart()
        }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the haze over the valley
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: chrome.warm
                property real density: 0.5
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g,
                                                       chrome.pal.neon.b, 1)
                opacity: 0.34          // haze, not paint — the frame stays glass
                // the air only moves while you're looking at it
                NumberAnimation on time {
                    running: chrome.awake
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                }
            }

            // the block behind the columns — rooms relight on every nav
            Facade {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -8
                anchors.bottomMargin: -8
                cols: Math.max(6, Math.floor(parent.width / 34))
                rows: Math.max(5, Math.floor(parent.height / 34))
                cell: 15
                gap: 9
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.07
                dim: 0.26 + 0.34 * chrome.warm
                flicker: chrome.awake
                spread: 700
                opacity: 0.7
                plan: {
                    const c = Math.max(6, Math.floor(parent.width / 34))
                    const r = Math.max(5, Math.floor(parent.height / 34))
                    const p = W.blank(c, r)
                    const seed = (chrome.navSeed + 1) * 7919
                    for (let i = 0; i < p.length; i++)
                        if ((((i + 1) * 2654435761 + seed) % 1009) / 1009 < 0.17) p[i] = 1
                    return p
                }
            }
        }
    }
}
