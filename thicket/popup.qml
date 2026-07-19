import QtQuick

// thicket: chrome for the Super+M control popup — a clearing you've been
// allowed into. The shell mounts these pieces around its shared tabs:
// backdrop (deep foliage glass with leaf silhouettes biting every edge and a
// dapple of warm light pooling from the top), header (the eyeshine pair +
// THICKET + three leaf-clusters that rustle with the music + how long it has
// watched), footer (what it hears on the wind + the send-off), overlay (a
// faint dark vignette pressing in at the corners). Item root that renders
// nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)    { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function emberA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function irisA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function leafA(a)   { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a)  { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }
    function dappleA(a) { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }

    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // the backdrop draws the clearing; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 12

    // ── backdrop: the clearing ──────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: chrome.glassA(0.95)
                border.width: 1
                border.color: chrome.leafA(0.6)
            }
            // dapple pooling down from the top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(110, parent.height * 0.35)
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.dappleA(0.10) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // leaves biting every edge of the clearing — one draw
            Canvas {
                id: bite
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: chrome.pal
                    function onDimChanged() { bite.requestPaint() }
                    function onGlassChanged() { bite.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height
                    function leafShape(x, y, len, wid, ang, fill) {
                        ctx.save()
                        ctx.translate(x, y); ctx.rotate(ang)
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.quadraticCurveTo(len * 0.42, -wid, len, -wid * 0.08)
                        ctx.quadraticCurveTo(len * 0.46, wid * 0.9, 0, 0)
                        ctx.closePath()
                        ctx.fillStyle = fill
                        ctx.fill()
                        ctx.restore()
                    }
                    for (let i = 0; i < 16; i++) {
                        const side = i % 4          // 0 top, 1 bottom, 2 left, 3 right
                        const f = chrome.rnd(i * 19 + 7)
                        let x, y, ang
                        if (side === 0)      { x = w * f; y = 5; ang = 0.5 + (chrome.rnd(i * 3) - 0.5) * 1.2 }
                        else if (side === 1) { x = w * f; y = h - 5; ang = -0.5 + (chrome.rnd(i * 3) - 0.5) * 1.2 + Math.PI }
                        else if (side === 2) { x = 5; y = h * f; ang = (chrome.rnd(i * 3) - 0.5) * 1.2 }
                        else                 { x = w - 5; y = h * f; ang = Math.PI + (chrome.rnd(i * 3) - 0.5) * 1.2 }
                        const teal = chrome.rnd(i * 41 + 6) < 0.3
                        leafShape(x, y, 15 + chrome.rnd(i * 17 + 9) * 14, 4 + chrome.rnd(i * 23) * 3.5,
                                  ang, teal ? "rgba(23,44,38,0.9)" : "rgba(5,9,7,0.9)")
                    }
                }
            }
        }
    }

    // ── header: the eyes + THICKET + rustle meter + how long it's watched ───
    readonly property Component header: Component {
        Column {
            spacing: 10

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // the eyeshine, blinking its slow deliberate blink
                    Item {
                        id: hdrEyes
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17; height: 6
                        transformOrigin: Item.Center
                        Rectangle {
                            x: 0; y: 1.5; width: 6; height: 4.5; radius: 2.25
                            color: chrome.pal.cyan
                            Rectangle { x: 1.5; y: 1; width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        Rectangle {
                            x: 11; y: 0; width: 6; height: 4.5; radius: 2.25
                            color: chrome.pal.cyan
                            Rectangle { x: 1.5; y: 1; width: 2; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.9) }
                        }
                        SequentialAnimation {
                            id: hdrBlink
                            NumberAnimation { target: hdrEyes; property: "scaleY"; to: 0.1; duration: 70 }
                            NumberAnimation { target: hdrEyes; property: "scaleY"; to: 1; duration: 120; easing.type: Easing.OutQuint }
                        }
                        Timer {
                            interval: 7000; repeat: true
                            running: chrome.popup.open
                            onTriggered: hdrBlink.restart()
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THICKET"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 5
                        color: chrome.pal.neon
                    }

                    // three leaf-clusters, leaning harder as their band rises
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.neon },
                                { band: "mid",  col: chrome.pal.amber },
                                { band: "high", col: chrome.pal.cyan }
                            ]
                            delegate: Item {
                                required property var modelData
                                readonly property real v: chrome.audio[modelData.band] || 0
                                width: 12; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { x: 5.5; y: 2; width: 1; height: 12; color: chrome.leafA(0.9) }
                                Rectangle {
                                    x: 0; y: 6 - parent.v * 4
                                    width: 7; height: 3.5; radius: 1.75
                                    rotation: -30 - parent.v * 45
                                    color: parent.v > 0.05 ? modelData.col : chrome.leafA(0.8)
                                }
                                Rectangle {
                                    x: 5; y: 9 - parent.v * 3
                                    width: 7; height: 3.5; radius: 1.75
                                    rotation: 30 + parent.v * 45
                                    color: parent.v > 0.3 ? modelData.col : chrome.leafA(0.8)
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "from cover"
                        font.family: chrome.serif
                        font.italic: true
                        font.pixelSize: 10
                        color: chrome.irisA(0.75)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "WATCHED " + chrome.popup.uptimeText.replace("up ", "").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.leafA(1.0)
                    }
                }
            }

            // a stem rule with a few leaflets, instead of a clean line
            Item {
                id: headRule
                width: parent.width
                height: 5
                Rectangle { y: 2; width: parent.width; height: 1; color: chrome.leafA(0.55) }
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        x: headRule.width * (0.12 + index * 0.24)
                        y: 0
                        width: 7; height: 3; radius: 1.5
                        rotation: index % 2 === 0 ? -26 : 200
                        color: chrome.emberA(0.5)
                    }
                }
            }
        }
    }

    // ── footer: the wind + the send-off ─────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 10

            Item {
                id: footRule
                width: parent.width
                height: 5
                Rectangle { y: 2; width: parent.width; height: 1; color: chrome.leafA(0.5) }
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        x: footRule.width * (0.2 + index * 0.28)
                        y: 1
                        width: 6; height: 2.5; radius: 1.25
                        rotation: index % 2 === 0 ? -24 : 204
                        color: chrome.leafA(0.9)
                    }
                }
            }

            Item {
                width: parent.width
                height: 14

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(chrome.popup.connType === "ethernet" ? 0xF059F
                            : chrome.popup.connType === "wifi" ? 0xF05A9 : 0xF092F)
                        font.family: chrome.icon
                        font.pixelSize: 11
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.irisA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "NOTHING ON THE WIND"
                            : (chrome.popup.connName || "ON THE WIND")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.inkA(0.75)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "move slow — it sees you"
                    font.family: chrome.serif
                    font.italic: true
                    font.pixelSize: 10
                    color: chrome.emberA(0.7)
                }
            }
        }
    }

    // ── overlay: the dark of the brush pressing in at the corners ──────────
    readonly property Component overlay: Component {
        Canvas {
            id: vig
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const w = width, h = height
                const corners = [[0, 0], [w, 0], [0, h], [w, h]]
                for (const c of corners) {
                    const g = ctx.createRadialGradient(c[0], c[1], 4, c[0], c[1], Math.min(w, h) * 0.4)
                    g.addColorStop(0, "rgba(3,6,5,0.28)")
                    g.addColorStop(1, "rgba(3,6,5,0)")
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                }
            }
        }
    }
}
