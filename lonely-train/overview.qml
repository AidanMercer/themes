import QtQuick

// lonely-train: night-carriage chrome for the Super+Tab exposé.
//
// The shell keeps the radial layout, live thumbnails and nav; this file makes
// every tile a carriage window on the last train home — slate window surround
// with a thin rubber-seal line inside, a warm lamp glow pooling at each sill,
// and the sodium station light landing on whichever window you're about to
// alight from. Behind it all: rain sliding down the glass and the odd station
// lamp drifting past. Same placard grammar as bar.qml / notif.qml.
//
// visual-only by contract: no input handlers anywhere; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // neon/cyan/magenta/amber/dim/text/glass
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property real ui: pal.uiScale

    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function duskA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    // uniform white nudged toward the sodium lamps — backlit-plaque ink
    function warmInk(t, a) {
        return Qt.rgba(pal.text.r + (pal.neon.r - pal.text.r) * t,
                       pal.text.g + (pal.neon.g - pal.text.g) * t,
                       pal.text.b + (pal.neon.b - pal.text.b) * t, a)
    }

    // ── scalars: night pushed back, carriage-window cards ──
    readonly property color scrimColor: Qt.rgba(pal.glass.r * 0.55, pal.glass.g * 0.65, pal.glass.b * 0.9, 1)
    readonly property real scrimOpacity: 0.6
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.95)
    readonly property color cardBorder: inkA(0.16)
    readonly property color cardBorderHot: pal.neon              // the lamp hits it
    readonly property color cardBorderCenter: duskA(0.65)        // your carriage
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: Math.round(10 * ui)
    readonly property color cardHighlight: inkA(0.05)
    readonly property color thumbBg: Qt.darker(pal.glass, 1.4)
    readonly property int thumbRadius: Math.round(6 * ui)
    readonly property color titleColor: warmInk(0.28, 0.85)      // destination plaque
    readonly property color titleHotColor: warmInk(0.5, 1.0)     // plaque backlit
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: serif
    readonly property color hintColor: warmInk(0.2, 0.6)
    readonly property string hintText: "↵ select   esc close"
    readonly property string emptyText: "no other windows"

    // ── backdrop: rain on the glass + a station lamp drifting past ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            opacity: chrome.overview.reveal

            // the odd station lamp sliding by behind everything — one soft
            // amber bloom, right to left (the world slides backwards, same
            // direction as particles.qml), a long dark pause between passes
            Canvas {
                id: lamp
                width: Math.round(420 * chrome.ui)
                height: width
                y: bd.height * 0.2
                x: -width - 60      // parked offstage until the first pass
                opacity: 0.5
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { lamp.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = width / 2
                    const g = ctx.createRadialGradient(c, c, 0, c, c, c)
                    g.addColorStop(0, chrome.amberA(0.3))
                    g.addColorStop(0.5, chrome.amberA(0.08))
                    g.addColorStop(1, chrome.amberA(0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
                SequentialAnimation on x {
                    running: chrome.overview.open
                    loops: Animation.Infinite
                    PauseAnimation { duration: 5200 }
                    NumberAnimation {
                        from: bd.width + 60; to: -lamp.width - 60
                        duration: 8000
                    }
                }
            }

            // sparse rain streaks, blown slightly back by the travel wind,
            // sliding down the glass. barely-there alpha, ten of them.
            Repeater {
                model: 10
                delegate: Rectangle {
                    id: drop
                    required property int index
                    readonly property real jitter: Math.random()
                    readonly property real len: (70 + jitter * 100) * chrome.ui
                    width: Math.max(1, Math.round(chrome.ui))
                    height: len
                    radius: width / 2
                    rotation: 6 + jitter * 4
                    x: (index + jitter * 0.8) / 10 * bd.width
                    y: -len
                    color: chrome.duskA(0.05 + jitter * 0.05)
                    SequentialAnimation on y {
                        running: chrome.overview.open
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -drop.len - drop.jitter * 700
                            to: bd.height + 10
                            duration: 9000 + drop.jitter * 9000
                        }
                    }
                }
            }
        }
    }

    // ── per-tile chassis, under the card: the window surround ──
    readonly property Component tileUnderlay: Component {
        Item {
            id: ur
            property var tile: null   // injected by the shell after load
            readonly property bool hot: tile ? tile.hot === true : false

            // sodium wash when the station light lands on this window —
            // wide soft ring first, then a crisper halo
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(-9 * chrome.ui)
                radius: chrome.cardRadius + Math.round(9 * chrome.ui)
                color: "transparent"
                border.width: Math.round(7 * chrome.ui)
                border.color: chrome.amberA(0.1)
                opacity: ur.hot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(-4 * chrome.ui)
                radius: chrome.cardRadius + Math.round(4 * chrome.ui)
                color: "transparent"
                border.width: 2
                border.color: chrome.amberA(0.28)
                opacity: ur.hot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
            // outer window frame — dim slate, the carriage wall around the glass
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(-3 * chrome.ui)
                radius: chrome.cardRadius + Math.round(3 * chrome.ui)
                color: "transparent"
                border.width: Math.round(3 * chrome.ui)
                border.color: Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.85)
            }
        }
    }

    // ── per-tile dressing, over the card: seal line + sill glow ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null   // injected by the shell after load
            readonly property bool hot: tile ? tile.hot === true : false
            readonly property bool ctr: tile ? tile.isCenter === true : false

            // inner seal — the thin rubber line just inside the frame
            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(4 * chrome.ui)
                radius: Math.max(2, chrome.cardRadius - Math.round(3 * chrome.ui))
                color: "transparent"
                border.width: 1
                border.color: chrome.inkA(0.1)
            }
            // carriage lamplight pooling at the sill; a touch warmer when
            // the window is lit. amberA(0) not "transparent" — keeps the
            // gradient interpolating in amber, not through black.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(2, chrome.cardRadius - 1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.amberA(0) }
                    GradientStop { position: 0.6; color: chrome.amberA(0) }
                    GradientStop { position: 1.0; color: chrome.amberA(ov.hot ? 0.16 : 0.09) }
                }
            }
            // quiet marker over the window you're already on
            Text {
                visible: ov.ctr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(7 * chrome.ui)
                text: "· current window ·"
                font.family: chrome.serif
                font.italic: true
                font.pixelSize: Math.round(11 * chrome.ui)
                color: chrome.duskA(0.75)
            }
        }
    }
}
