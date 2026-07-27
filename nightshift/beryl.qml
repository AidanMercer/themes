import QtQuick
import "windows.js" as W

// nightshift: chrome for the beryl browser. The page covers most of the window
// (an opaque scrim sits behind every view), so this is designed for the CHROME
// BANDS — the tab strip, the seam under it, the status bar, the window margins
// — and not for the middle, which the user would only see through a
// transparent page.
//
// Every tab is a window in somebody else's building: the strip along the seam
// carries one room per open surface, and a navigation sends the sodium through.
Item {
    id: chrome

    // injected by beryl's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : true
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    // glass, not a wall — this is what the chrome bands and margins are made of
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.40)
    readonly property color cardBorder: hazeA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3
    readonly property string wordmark: "◇ far windows"

    property real warm: 0
    property int navSeed: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 1; duration: 170; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 1400; easing.type: Easing.InOutSine }
    }
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

            // haze banked into the top band, where the tab strip lives
            ShaderEffect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.min(parent.height, 130)
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: chrome.warm
                property real density: 0.6
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g,
                                                       chrome.pal.neon.b, 1)
                opacity: 0.38          // haze, not paint — the bands stay glass
                NumberAnimation on time {
                    running: chrome.awake
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                }
            }

            // the seam under the tab strip: a run of rooms across the whole
            // width, relighting on every navigation
            Facade {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2
                cols: Math.max(20, Math.floor(parent.width / 12))
                rows: 1
                cell: 6
                gap: 6
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.16
                dim: 0.34 + 0.5 * chrome.warm
                flicker: chrome.awake
                spread: 620
                opacity: 0.8
                plan: {
                    const c = Math.max(20, Math.floor(parent.width / 12))
                    const p = W.blank(c, 1)
                    const seed = (chrome.navSeed + 1) * 3671
                    for (let i = 0; i < c; i++)
                        if ((((i + 1) * 2654435761 + seed) % 733) / 733 < 0.24) p[i] = 1
                    return p
                }
            }
        }
    }

    // the status bar's own kerb light, above the page
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                height: 1
                color: chrome.sodiumA(0.10 + 0.35 * chrome.warm)
            }
        }
    }
}
