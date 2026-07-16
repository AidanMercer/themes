import QtQuick

// fuel: forecourt chrome for the Super+Tab exposé.
//
// The shell keeps the radial layout, live thumbnails and nav; this file makes
// the ring read as the station at 3am: pump-screen cards with thin icy tube
// borders, a price-board bay number riding every tile, and the canopy's
// signature neon stripe bending the top-right corner of whichever card you're
// about to pull up to — humming softly, the way a gas sign never quite holds
// steady. Behind the ring: a cold vignette, a low amber horizon with a
// roadside FUEL sign, and once in a long while a tail-light streak gliding by.
// Visual-only by contract: no input handlers; every loop gates on
// overview.open (the shell tears the layers down ~300ms after close).
Item {
    id: chrome

    required property var pal        // ThemePalette — neon/cyan/magenta/amber/dim
    required property var overview   // exposé root — open, reveal, selected, tiles…

    readonly property string mono: pal.fontMono
    readonly property real ui: pal.uiScale
    // Canvas gradients want css strings, not color objects
    function css(c, a) { return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")" }

    // ── scalars: pump-screen cards on a night-wash scrim ──
    readonly property color scrimColor: pal.glass
    readonly property real scrimOpacity: 0.58
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: Qt.alpha(pal.cyan, 0.32)   // idle tube, barely lit
    readonly property color cardBorderHot: pal.cyan                // tube at full brightness
    readonly property color cardBorderCenter: Qt.alpha(pal.cyan, 0.6)
    readonly property int cardBorderWidth: 1
    readonly property int cardBorderWidthHot: 1
    readonly property int cardBorderWidthCenter: 1
    readonly property int cardRadius: Math.round(3 * ui)           // squared, like the pump screen
    readonly property color cardHighlight: "transparent"           // the tube lights the edge, not a sheen
    readonly property color thumbBg: Qt.darker(pal.glass, 1.6)
    readonly property int thumbRadius: 2
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.55)
    readonly property color titleColor: Qt.alpha(pal.text, 0.66)   // pump-screen warm off-white
    readonly property color titleHotColor: pal.text
    readonly property string titleFont: pal.fontMono
    readonly property string hintFont: pal.fontMono
    readonly property color hintColor: Qt.alpha(pal.cyan, 0.7)
    readonly property string hintText: "◄ ► ▲ ▼  SELECT GRADE      ↵  TO FUEL      ESC  DRIVE OFF"
    readonly property string emptyText: "STATION EMPTY · 24 HR"

    // ── backdrop: cold vignette + low amber horizon + roadside sign ──
    readonly property Component backdrop: Component {
        Item {
            id: bd
            readonly property int horizonY: Math.round(bd.height * 0.72)

            // cold night pressing in from the screen edges
            Canvas {
                id: vig
                anchors.fill: parent
                opacity: 0.85 * chrome.overview.reveal
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                // pal reads config.toml async — retint if it lands after first paint
                Connections {
                    target: chrome.pal
                    function onGlassChanged() { vig.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const cx = width / 2, cy = height / 2
                    const r = Math.hypot(cx, cy)
                    const cold = Qt.darker(chrome.pal.glass, 1.35)
                    const g = ctx.createRadialGradient(cx, cy, r * 0.42, cx, cy, r)
                    g.addColorStop(0, chrome.css(cold, 0))
                    g.addColorStop(0.72, chrome.css(cold, 0.22))
                    g.addColorStop(1, chrome.css(cold, 0.6))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, width, height)
                }
            }

            // the road: one thin horizon line, amber under the station,
            // cooling to dim traces before it falls off the ends
            Rectangle {
                y: bd.horizonY
                width: bd.width
                height: 1
                opacity: 0.85 * chrome.overview.reveal
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: "transparent" }
                    GradientStop { position: 0.18; color: Qt.alpha(chrome.pal.dim, 0.6) }
                    GradientStop { position: 0.5;  color: Qt.alpha(chrome.pal.amber, 0.75) }
                    GradientStop { position: 0.82; color: Qt.alpha(chrome.pal.dim, 0.6) }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
            // its faint bloom on the wet asphalt
            Rectangle {
                y: bd.horizonY + 1
                width: bd.width; height: Math.round(3 * chrome.ui)
                opacity: 0.07 * chrome.overview.reveal
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: chrome.pal.amber }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // roadside sign, planted just off the shoulder
            Column {
                id: signCol
                x: Math.round(bd.width * 0.055)
                y: bd.horizonY - height - Math.round(12 * chrome.ui)
                spacing: 3
                opacity: chrome.overview.reveal
                Text {
                    text: "FUEL"
                    font.family: chrome.mono
                    font.weight: Font.Black
                    font.pixelSize: Math.round(15 * chrome.ui)
                    font.letterSpacing: 6
                    color: chrome.pal.neon
                }
                Text {
                    text: "BAYS " + String(chrome.overview.windows.length).padStart(2, "0") + " · 24 HR"
                    font.family: chrome.mono
                    font.pixelSize: Math.round(8 * chrome.ui)
                    font.letterSpacing: 2
                    color: Qt.alpha(chrome.pal.cyan, 0.65)
                }
            }
            // the post it hangs on
            Rectangle {
                x: signCol.x + 1; y: signCol.y + signCol.height + 3
                width: 2; height: Math.max(0, bd.horizonY - y)
                color: Qt.alpha(chrome.pal.text, 0.16)
                opacity: chrome.overview.reveal
            }

            // once in a while a distant car glides by — a lone tail-light
            // streak just above the horizon, then night again
            Item {
                id: car
                x: bd.width; y: bd.horizonY - 3
                width: Math.round(110 * chrome.ui); height: 2
                opacity: 0
                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0;  color: chrome.pal.magenta }
                        GradientStop { position: 0.25; color: Qt.alpha(chrome.pal.magenta, 0.4) }
                        GradientStop { position: 1.0;  color: "transparent" }
                    }
                }
                SequentialAnimation {
                    running: chrome.overview.open
                    loops: Animation.Infinite
                    PauseAnimation { duration: 9000 }
                    ScriptAction { script: { car.x = bd.width; car.opacity = 0.55 } }
                    NumberAnimation { target: car; property: "x"; to: -car.width; duration: 4200; easing.type: Easing.InOutSine }
                    ScriptAction { script: car.opacity = 0 }
                }
            }
        }
    }

    // ── per-tile dressing: bay number chip + the corner-bending canopy stripe ──
    readonly property Component tileOverlay: Component {
        Item {
            id: ov
            property var tile: null   // injected by the shell after load
            readonly property bool hot: ov.tile ? ov.tile.hot === true : false
            readonly property bool ctr: ov.tile ? ov.tile.isCenter === true : false

            // price-board bay number riding the top-left edge — dark chip, amber pump digits
            Rectangle {
                x: Math.round(9 * chrome.ui); y: -Math.round(7 * chrome.ui)
                width: bayTxt.implicitWidth + Math.round(10 * chrome.ui)
                height: Math.round(14 * chrome.ui)
                radius: 2
                color: Qt.darker(chrome.pal.glass, 1.3)
                border.color: ov.hot ? Qt.alpha(chrome.pal.amber, 0.8) : Qt.alpha(chrome.pal.dim, 0.7)
                border.width: 1
                Text {
                    id: bayTxt
                    anchors.centerIn: parent
                    text: "Nº " + String((ov.tile ? ov.tile.index : 0) + 1).padStart(2, "0")
                    font.family: chrome.mono
                    font.weight: Font.Bold
                    font.pixelSize: Math.round(8 * chrome.ui)
                    font.letterSpacing: 1
                    color: chrome.pal.amber
                }
            }

            // the focused window's bay is the one being served
            Text {
                visible: ov.ctr
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: Math.round(7 * chrome.ui)
                text: "· NOW SERVING ·"
                font.family: chrome.mono
                font.pixelSize: Math.round(9 * chrome.ui)
                font.letterSpacing: 3
                color: Qt.alpha(chrome.pal.cyan, 0.85)
            }

            // the signature: canopy neon bending the top-right corner of the
            // hot card — an L of tube hugging the edge, glow under crisp
            // stroke, wavering like a sign that never quite holds steady
            Item {
                id: stripe
                anchors.fill: parent
                visible: ov.hot
                readonly property real t: 3 * chrome.ui
                readonly property real runH: parent.width * 0.46
                readonly property real runV: parent.height * 0.42

                // fake glow: wide, low alpha, same L
                Rectangle {
                    x: stripe.width - stripe.runH; y: -Math.round(4 * chrome.ui)
                    width: stripe.runH + Math.round(4 * chrome.ui); height: Math.round(9 * chrome.ui)
                    radius: height / 2
                    color: Qt.alpha(chrome.pal.neon, 0.15)
                }
                Rectangle {
                    x: stripe.width - Math.round(4 * chrome.ui); y: -Math.round(4 * chrome.ui)
                    width: Math.round(9 * chrome.ui); height: stripe.runV + Math.round(4 * chrome.ui)
                    radius: width / 2
                    color: Qt.alpha(chrome.pal.neon, 0.15)
                }
                // the tube: horizontal run into the bend…
                Rectangle {
                    x: stripe.width - stripe.runH; y: -stripe.t / 2
                    width: stripe.runH + stripe.t / 2; height: stripe.t
                    radius: stripe.t / 2
                    color: chrome.pal.neon
                }
                // …and down the right edge
                Rectangle {
                    x: stripe.width - stripe.t / 2; y: -stripe.t / 2
                    width: stripe.t; height: stripe.runV + stripe.t / 2
                    radius: stripe.t / 2
                    color: chrome.pal.neon
                }

                SequentialAnimation on opacity {
                    running: ov.hot && chrome.overview.open
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.78; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0;  duration: 1100; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
