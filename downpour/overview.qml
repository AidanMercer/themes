import QtQuick

// downpour: fog chrome for the Super+Tab exposé. Zooming out is stepping
// back from the window: the whole glass is fogged (a deep navy scrim with a
// breath vignette and beads sitting where they always sit), and every open
// window is a wiped-clear pane in the mist — a soft halo of spreading breath
// behind each card. The pane under your eye gathers a droplet at its lower
// rim, growing while you linger; the window you came from keeps one warm
// rose bead — the room behind you. Visual-only by contract: no input
// handlers; every loop gates on overview.open.
Item {
    id: chrome

    required property var pal        // neon=pane light, cyan=her skin light,
                                     // magenta=the warmth, dim=frame slate
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string serif: "Noto Serif"
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function paneA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // ── scalars: fogged glass, soft rims, no hard chrome ──
    readonly property color scrimColor: "#050b18"
    readonly property real scrimOpacity: 0.72
    readonly property bool shadowOn: false                  // breath halos instead
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.92)
    readonly property color cardBorder: inkA(0.14)
    readonly property color cardBorderHot: paneA(0.85)
    readonly property color cardBorderCenter: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.6)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 16
    readonly property color cardHighlight: inkA(0.16)
    readonly property color thumbBg: "#060d1a"
    readonly property int thumbRadius: 12
    readonly property color titleColor: inkA(0.55)
    readonly property color titleHotColor: inkA(0.92)
    readonly property string titleFont: serif
    readonly property string hintFont: serif
    readonly property color hintColor: inkA(0.42)
    readonly property string hintText: "every pane holds a life · ⏎ step through"
    readonly property string emptyText: "no one at the window"

    // ── backdrop: the fogged glass itself ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // breath vignette — the mist is thickest at the edges
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: chrome.inkA(0.05) }
                    GradientStop { position: 0.4; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.inkA(0.04) }
                }
            }

            // beads sitting where they always sit — a few breathe, slowly
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    readonly property real fx: chrome.rnd(index * 73 + 5)
                    readonly property real fy: chrome.rnd(index * 41 + 9)
                    x: bd.width * (0.03 + fx * 0.94)
                    y: bd.height * (0.04 + fy * 0.9)
                    width: 4 + (index % 3) * 1.8
                    height: width * 1.25
                    radius: width / 2
                    color: chrome.paneA(0.30)
                    Rectangle {
                        x: parent.width * 0.22; y: parent.width * 0.22
                        width: parent.width * 0.26; height: width
                        radius: width / 2
                        color: chrome.inkA(0.6)
                    }
                    SequentialAnimation on opacity {
                        running: chrome.overview.open && index % 4 === 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 3200 + index * 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 3200 + index * 400; easing.type: Easing.InOutSine }
                    }
                }
            }

            // her line, written low on the fog
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: bd.height * 0.045
                text: String(chrome.overview.windows.length) + " lit against the storm"
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: 14
                font.letterSpacing: 2
                color: chrome.inkA(0.4)
            }
        }
    }

    // ── per-tile: the breath spreading behind each wiped pane ──
    readonly property Component tileUnderlay: Component {
        Item {
            property var tile: null
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 44
                height: parent.height + 44
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.inkA(0.07) }
                    GradientStop { position: 0.65; color: chrome.inkA(0.025) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ── per-tile: the lingering droplet + the warm bead of home ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // the glint where the wipe crossed this pane
            Rectangle {
                x: 12; y: 8
                width: 26; height: 3
                radius: 1.5
                rotation: -18
                color: chrome.inkA(ov.hot ? 0.35 : 0.14)
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            // linger and a droplet gathers on the pane's lower rim
            Rectangle {
                id: lingerBead
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: -3
                width: 7
                height: ov.hot ? 12 : 0
                radius: 3.5
                color: chrome.paneA(0.8)
                Behavior on height { NumberAnimation { duration: 900; easing.type: Easing.InOutSine } }
                Rectangle {
                    x: 1.4; y: 2
                    width: 1.8; height: 1.8; radius: 0.9
                    color: chrome.inkA(0.8)
                    visible: lingerBead.height > 5
                }
            }

            // the room you came from keeps one warm bead
            Rectangle {
                visible: ov.ctr
                x: parent.width - 16
                y: 8
                width: 6; height: 7.4
                radius: 3
                color: Qt.rgba(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 0.85)
                Rectangle { x: 1.2; y: 1.4; width: 1.7; height: 1.7; radius: 0.9; color: chrome.inkA(0.85) }
            }
        }
    }
}
