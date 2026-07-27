import QtQuick
import "windows.js" as W

// nightshift: chrome for the cobalt Teams client. This is the app Aidan takes
// calls in, so it gets the quietest room on the street: the backdrop mounts
// UNDER the glass bars and the page, so a little of the district surfaces
// through cobalt's stripped-transparent regions and faintly through the bars,
// and nothing at all moves over the top of a conversation.
//
// A rail switch is the only flourish, and it's one slow breath of sodium.
Item {
    id: chrome

    // injected by cobalt's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : true
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    readonly property string wordmark: "◉ on call"

    property real warm: 0
    property int navSeed: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 0.55; duration: 320; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 2100; easing.type: Easing.InOutSine }
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

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: chrome.warm
                property real density: 0.38            // restrained; people are talking
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g,
                                                       chrome.pal.neon.b, 1)
                opacity: 0.28          // haze, not paint — the bars stay glass
                NumberAnimation on time {
                    running: chrome.awake
                    from: 0; to: 3600; duration: 4200000
                    loops: Animation.Infinite
                }
            }

            // a low skyline along the bottom, under the status line
            Facade {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -4
                height: 64
                cols: Math.max(12, Math.floor(parent.width / 28))
                rows: 3
                cell: 12
                gap: 7
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.08
                dim: 0.18 + 0.26 * chrome.warm
                flicker: false                          // no twitching during a call
                spread: 1600
                opacity: 0.5
                plan: {
                    const c = Math.max(12, Math.floor(parent.width / 28))
                    const p = W.blank(c, 3)
                    const seed = (chrome.navSeed + 1) * 2741
                    for (let i = 0; i < p.length; i++)
                        if ((((i + 1) * 2654435761 + seed) % 691) / 691 < 0.14) p[i] = 1
                    return p
                }
            }
        }
    }
}
