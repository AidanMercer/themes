import QtQuick

// stillwater: lights on the far shore — chrome for the Super+Tab exposé.
//
// the exposé becomes the water at dusk: a deep navy scrim, one enormous
// horizon line drawn clear across the screen behind the ring of windows,
// and the house law applied to every window — each tile is a lit window on
// the far shore, so each tile gets a REFLECTION: a soft inverted slab of
// light beneath it that brightens when the tile is under consideration.
// the selected tile's lamp lights on its top edge; the focused (center)
// window carries a small dusk-rose mooring ring. everything eases slow and
// sine — nothing snaps on still water.
//
// visual-only by contract: no input handlers; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=lamp white, cyan=twilight, magenta=rose
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    function px(v) { return Math.round(v * pal.uiScale) }
    function lampA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function skyA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    // ── scalars: soft water glass ──
    // scrim + thumb wells are fixed deep-water tones a shade darker than
    // pal.glass — deliberately below any palette accent so the wallpaper's
    // own dusk reads through; retinting config.toml shouldn't lift the night
    readonly property color scrimColor: "#08182c"
    readonly property real scrimOpacity: 0.72
    readonly property bool shadowOn: false                  // the reflection replaces it
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, 0.9)
    readonly property color cardBorderHot: pal.neon
    readonly property color cardBorderCenter: Qt.rgba(pal.magenta.r, pal.magenta.g, pal.magenta.b, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 10
    readonly property color cardHighlight: lampA(0.10)
    readonly property color thumbBg: "#071527"
    readonly property int thumbRadius: 8
    readonly property color titleColor: skyA(0.8)
    readonly property color titleHotColor: pal.neon
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: skyA(0.7)
    readonly property string hintText: "the water shows every window · ⏎ to cross"
    readonly property string emptyText: "nothing on the water tonight"

    // ── backdrop: the horizon behind the ring ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            readonly property real hy: Math.round(bd.height * 0.5)

            // the sky remembers the dusk: a whisper of rose above the line
            Rectangle {
                x: 0; y: bd.hy - px(90)
                width: parent.width
                height: px(90)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 0.05) }
                }
            }
            // the water holds a little of it below
            Rectangle {
                x: 0; y: bd.hy
                width: parent.width
                height: px(120)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.05) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // THE line
            Rectangle {
                x: 0; y: bd.hy
                width: parent.width
                height: 1
                color: chrome.skyA(0.28)
            }
            // distant lamps on it, breathing very slowly while the exposé is up
            Repeater {
                model: 9
                Item {
                    id: shoreLamp
                    required property int index
                    readonly property real fx: (((index * 73) % 97) / 97)
                    readonly property real seed: ((index * 0.61803) % 1)
                    x: Math.round(bd.width * (0.05 + fx * 0.9))
                    y: bd.hy
                    Rectangle {
                        id: dot
                        x: -1.5; y: -2
                        width: 3; height: 3
                        radius: 1.5
                        color: chrome.lampA(0.5 + shoreLamp.seed * 0.4)
                        SequentialAnimation on opacity {
                            running: chrome.overview.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4 + shoreLamp.seed * 0.2; duration: 2600 + shoreLamp.index * 300; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2600 + shoreLamp.index * 300; easing.type: Easing.InOutSine }
                        }
                    }
                    Column {
                        x: -1; y: 3
                        spacing: 2
                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                width: 2; height: 2
                                color: chrome.lampA(0.22 - index * 0.09)
                            }
                        }
                    }
                }
            }

            // the evening's tally, top-left, in the house dialect
            Text {
                x: px(30); y: px(28)
                text: "across the water · " + String(chrome.overview.windows.length) + " lit"
                font.family: chrome.mono
                font.pixelSize: px(10)
                font.letterSpacing: 3
                color: chrome.skyA(0.65)
            }
        }
    }

    // ── per-tile: the reflection — the house law applied to windows ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: un
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            // the inverted slab of light beneath the tile
            Rectangle {
                x: 0
                y: parent.height + px(5)
                width: parent.width
                height: parent.height * 0.30
                radius: chrome.cardRadius
                opacity: un.hot ? 0.75 : 0.45
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: un.hot ? chrome.lampA(0.16) : chrome.skyA(0.12) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // a waterline seam between window and double
            Rectangle {
                x: px(4)
                y: parent.height + px(3)
                width: parent.width - px(8)
                height: 1
                color: chrome.skyA(un.hot ? 0.4 : 0.2)
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // ── per-tile: the lamp lights when the window is considered ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // selected: a lamp on the tile's top edge, glowing softly
            Item {
                visible: ov.hot
                anchors.horizontalCenter: parent.horizontalCenter
                y: -px(3)
                Rectangle {
                    x: -px(3); y: -px(3)
                    width: px(6); height: px(6)
                    radius: px(3)
                    color: chrome.pal.neon
                    SequentialAnimation on opacity {
                        running: ov.hot && chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }

            // the focused window's mooring: a small dusk-rose ring, top-left
            Rectangle {
                visible: ov.ctr
                x: px(8); y: -px(8)
                width: px(11); height: px(11)
                radius: px(5.5)
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 0.85)
            }
        }
    }
}
