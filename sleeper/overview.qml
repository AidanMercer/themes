import QtQuick

// sleeper: the corridor. Step out of your berth (Super+Tab) and the windows
// hang along the sleeping car's corridor: every window is a compartment,
// framed in wood with a small brass berth number, the red runner carpet
// stretching along the floor below them. The compartment you're pointing at
// gets its corridor lamp lit — a warm glow pooling under the frame — and
// your own berth wears the ☾ tag. Now and then a lamp passes down the
// corridor (light arrives as passing glows). Everything rocks nothing:
// the corridor is the one still place in the fiction — you're standing up.
//
// visual-only by contract: no input handlers; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon=city green, cyan=moon pale,
                                     // magenta=stamp red, amber=tea, dim=wood
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // ── scalars: wood frames, warm lamps ──
    readonly property color scrimColor: "#0b0d08"
    readonly property real scrimOpacity: 0.72
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.96)
    readonly property color cardBorder: Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, 0.9)
    readonly property color cardBorderHot: pal.amber
    readonly property color cardBorderCenter: Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, 0.65)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 2
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: 4
    readonly property color thumbBg: "#0a0c08"
    readonly property int thumbRadius: 3
    readonly property color titleColor: linenA(0.6)
    readonly property color titleHotColor: pal.amber
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: linenA(0.55)
    readonly property string hintText: "CHOOSE A COMPARTMENT · ⏎ SETTLE IN · ESC STAY PUT"
    readonly property string emptyText: "THE CAR IS EMPTY TONIGHT"

    // ── backdrop: the corridor floor + a passing lamp ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // the red runner carpet along the corridor floor
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(26 * chrome.pal.uiScale)
                width: parent.width
                height: Math.round(14 * chrome.pal.uiScale)
                color: Qt.rgba(chrome.pal.magenta.r * 0.5, chrome.pal.magenta.g * 0.28,
                               chrome.pal.magenta.b * 0.24, 0.35)
            }
            Rectangle {   // carpet borders
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(40 * chrome.pal.uiScale)
                width: parent.width; height: 1
                color: chrome.teaA(0.35)
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(25 * chrome.pal.uiScale)
                width: parent.width; height: 1
                color: chrome.teaA(0.35)
            }

            // wood panelling rule near the ceiling
            Rectangle {
                y: Math.round(30 * chrome.pal.uiScale)
                width: parent.width; height: 1
                color: chrome.woodA(0.5)
            }

            // the car tag, top-left, in the plaque's dialect
            Row {
                x: Math.round(30 * chrome.pal.uiScale)
                y: Math.round(38 * chrome.pal.uiScale)
                spacing: 8
                Text {
                    text: "☾"
                    font.pixelSize: Math.round(11 * chrome.pal.uiScale)
                    color: chrome.pal.cyan
                }
                Text {
                    text: "CAR 7 · " + String(chrome.overview.windows.length).padStart(2, "0") + " ABOARD"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(10 * chrome.pal.uiScale)
                    font.letterSpacing: 3
                    color: chrome.teaA(0.85)
                }
            }

            // a lamp passing down the corridor, slow, while it's open
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                width: bd.width * 0.28
                height: bd.height * 1.5
                y: -bd.height * 0.25
                x: -width + (bd.width + width * 2) * Math.max(0, t)
                rotation: 10
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.05) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                running: chrome.overview.open
                loops: Animation.Infinite
                PropertyAction { target: passing; property: "t"; value: 0 }
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 3200; easing.type: Easing.InOutSine }
                PropertyAction { target: passing; property: "t"; value: -1 }
                PauseAnimation { duration: 6500 }
            }
        }
    }

    // ── per-tile: the corridor lamp pooling under the chosen compartment ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: under
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            // warm light pooling below the frame when the lamp is on you
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 2
                width: parent.width * 0.8
                height: Math.round(18 * chrome.pal.uiScale)
                radius: height / 2
                opacity: under.hot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutSine } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.22) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
        }
    }

    // ── per-tile: brass berth number + your berth's tag ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // brass berth-number plate, top-left of the frame
            Rectangle {
                x: Math.round(6 * chrome.pal.uiScale)
                y: -Math.round(9 * chrome.pal.uiScale)
                width: plateT.implicitWidth + Math.round(10 * chrome.pal.uiScale)
                height: Math.round(15 * chrome.pal.uiScale)
                radius: 2
                color: "#0c0e0a"
                border.width: 1
                border.color: ov.hot ? chrome.pal.amber : chrome.woodA(0.9)
                Text {
                    id: plateT
                    anchors.centerIn: parent
                    text: String((ov.tile ? ov.tile.index : 0) + 1).padStart(2, "0")
                    font.family: chrome.mono
                    font.pixelSize: Math.round(9 * chrome.pal.uiScale)
                    color: ov.hot ? chrome.pal.amber : chrome.linenA(0.6)
                }
            }

            // your own berth wears the moon
            Rectangle {
                visible: ov.ctr
                anchors.right: parent.right
                anchors.rightMargin: Math.round(6 * chrome.pal.uiScale)
                y: -Math.round(9 * chrome.pal.uiScale)
                width: moonT.implicitWidth + Math.round(10 * chrome.pal.uiScale)
                height: Math.round(15 * chrome.pal.uiScale)
                radius: 2
                color: "#0c0e0a"
                border.width: 1
                border.color: Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.7)
                Text {
                    id: moonT
                    anchors.centerIn: parent
                    text: "☾ YOURS"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(8 * chrome.pal.uiScale)
                    color: chrome.pal.cyan
                }
            }

            // sill line at the foot of the window
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.94
                height: 1
                color: ov.hot ? chrome.teaA(0.8) : chrome.woodA(0.6)
            }
        }
    }
}
