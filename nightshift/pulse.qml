import QtQuick
import "windows.js" as W

// nightshift: chrome for the pulse system monitor. This is the one surface
// where the district's occupancy IS the data — the block behind the gauges
// fills with load, so a busy machine is a building where nearly every room is
// awake and an idle one is three lights on the whole street.
//
// Sending a signal to a process is the violent act in this app, so a kill
// throws the beacon across the facade: the only red in a blue city, and it
// blinks rather than glows.
Item {
    id: chrome

    // injected by pulse's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : true
    readonly property real load: host && host.load !== undefined ? host.load : 0
    readonly property real memLoad: host && host.memLoad !== undefined ? host.memLoad : 0
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    // glass, not a wall — the city stays visible behind the gauges
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.40)
    readonly property color cardBorder: hazeA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3
    readonly property string wordmark: "▦ the grid"

    // a re-sort is a light event; a kill is a heavy one
    property real warm: 0
    property real alarm: 0
    property int sortSeed: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 0.7; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 1200; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: beacon
        running: false
        loops: 3
        NumberAnimation { target: chrome; property: "alarm"; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "alarm"; to: 0; duration: 230; easing.type: Easing.InQuad }
    }
    Connections {
        target: chrome.host
        enabled: chrome.host !== null
        function onSortIdChanged() { chrome.sortSeed++; if (chrome.awake) surge.restart() }
        function onKillPulseChanged() { if (chrome.awake) beacon.restart() }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: Math.max(chrome.warm, chrome.alarm)
                property real density: 0.4 + 0.32 * chrome.load
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: chrome.alarm > 0.02
                    ? Qt.vector4d(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 1)
                    : Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 1)
                opacity: 0.34          // haze, not paint — the frame stays glass
                // the haze churns faster as the machine works harder
                NumberAnimation on time {
                    running: chrome.awake
                    from: 0; to: 3600
                    duration: Math.round(3600000 / (1 + chrome.load * 2.5))
                    loops: Animation.Infinite
                }
            }

            // the district: occupancy tracks load, one room at a time
            Facade {
                id: grid
                anchors.fill: parent
                anchors.margins: -6
                readonly property int cc: Math.max(8, Math.floor(parent.width / 30))
                readonly property int rr: Math.max(6, Math.floor(parent.height / 30))
                cols: cc
                rows: rr
                cell: 13
                gap: 8
                lit: chrome.alarm > 0.02 ? chrome.pal.magenta : chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.07
                dim: 0.24 + 0.30 * chrome.load + 0.3 * chrome.alarm
                flicker: chrome.awake
                spread: 800
                opacity: 0.66
                plan: {
                    const c = grid.cc, r = grid.rr
                    const p = W.blank(c, r)
                    // how much of the street is awake — quantized so the facade
                    // changes in steps, room by room, not as a smooth dimmer
                    const fill = 0.05 + Math.round(chrome.load * 12) / 12 * 0.38
                    const seed = (chrome.sortSeed + 1) * 5233
                    for (let i = 0; i < p.length; i++)
                        if ((((i + 1) * 2654435761 + seed) % 1021) / 1021 < fill) p[i] = 1
                    return p
                }
            }
        }
    }
}
