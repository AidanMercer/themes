import QtQuick

// nature — "golden hour" chrome for the Super+M control popup: garden glass.
//
// A warm dark-pine glass card with organic rounded corners and a honey-gold
// edge. The backdrop grows a twig with leaves down the left inside edge and
// floats a few soft bokeh discs behind the content; the header carries a
// blossom, the theme's name and a tiny meadow EQ (three grass blades that
// sway with the live audio bands); the footer roots the card with the
// connection and a sign-off. Renders nothing itself — the shell mounts the
// Components below around its shared tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette
    required property var popup    // popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color gold:  pal.neon
    readonly property color leaf:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color cream: pal.text
    readonly property color pine:  pal.glass
    readonly property real ui: pal.uiScale
    readonly property string serif: "Noto Serif Display"
    readonly property string icon:  "Symbols Nerd Font"
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }
    function leafA(a)  { return Qt.rgba(leaf.r, leaf.g, leaf.b, a) }
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }

    // the card itself: warm translucent pine glass, soft organic radius
    readonly property color cardBg: Qt.rgba(pine.r, pine.g, pine.b, 0.93)
    readonly property color cardBorder: goldA(0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: Math.round(18 * ui)

    // ── backdrop: bokeh discs + a leafy twig down the left edge ─────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: garden
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { garden.requestPaint() }
                    function onCyanChanged() { garden.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    if (w <= 0 || h <= 0) return
                    // soft bokeh discs, like the sun through the leaves
                    const discs = [
                        { x: w * 0.86, y: h * 0.12, r: 46, a: 0.05 },
                        { x: w * 0.72, y: h * 0.30, r: 26, a: 0.04 },
                        { x: w * 0.16, y: h * 0.85, r: 38, a: 0.045 },
                        { x: w * 0.90, y: h * 0.78, r: 30, a: 0.04 }
                    ]
                    for (const d of discs) {
                        ctx.beginPath()
                        ctx.arc(d.x, d.y, d.r * chrome.ui, 0, Math.PI * 2)
                        ctx.fillStyle = chrome.goldA(d.a)
                        ctx.fill()
                    }
                    // the twig: a curved stem down the left inside edge
                    const sx = 13 * chrome.ui
                    ctx.strokeStyle = chrome.leafA(0.4)
                    ctx.lineWidth = 1.3 * chrome.ui
                    ctx.beginPath()
                    ctx.moveTo(sx, h * 0.1)
                    ctx.bezierCurveTo(sx + 6 * chrome.ui, h * 0.35,
                                      sx - 5 * chrome.ui, h * 0.62, sx + 2 * chrome.ui, h * 0.9)
                    ctx.stroke()
                    // leaves budding off the twig
                    const leafSpots = [0.2, 0.38, 0.55, 0.72, 0.86]
                    for (let i = 0; i < leafSpots.length; i++) {
                        const t = leafSpots[i]
                        const lx = sx + Math.sin(t * 9) * 4 * chrome.ui
                        const ly = h * (0.1 + t * 0.8)
                        ctx.save()
                        ctx.translate(lx, ly)
                        ctx.rotate((i % 2 === 0 ? -1 : 1) * 1.0 + t)
                        ctx.beginPath()
                        ctx.ellipse(0, -2.6 * chrome.ui, 9 * chrome.ui, 5.2 * chrome.ui)
                        ctx.fillStyle = chrome.leafA(0.35 + (i % 2) * 0.12)
                        ctx.fill()
                        ctx.restore()
                    }
                    // one small blossom where the twig starts
                    const bx = sx, by = h * 0.1
                    ctx.fillStyle = chrome.creamA(0.5)
                    for (let k = 0; k < 5; k++) {
                        const a = k * Math.PI * 2 / 5 - Math.PI / 2
                        ctx.beginPath()
                        ctx.ellipse(bx + Math.cos(a) * 3.4 * chrome.ui - 2.2 * chrome.ui,
                                    by + Math.sin(a) * 3.4 * chrome.ui - 2.2 * chrome.ui,
                                    4.4 * chrome.ui, 4.4 * chrome.ui)
                        ctx.fill()
                    }
                    ctx.beginPath()
                    ctx.arc(bx, by, 1.8 * chrome.ui, 0, Math.PI * 2)
                    ctx.fillStyle = chrome.goldA(0.8)
                    ctx.fill()
                }
            }
        }
    }

    // ── header: blossom + name + meadow EQ, uptime on the right ────────────
    readonly property Component header: Component {
        Column {
            spacing: Math.round(12 * chrome.ui)

            Item {
                width: parent.width
                height: Math.round(18 * chrome.ui)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(14 * chrome.ui)   // clear the twig
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(8 * chrome.ui)

                    // five-petal blossom pip
                    Canvas {
                        id: headBloom
                        width: Math.round(14 * chrome.ui)
                        height: Math.round(14 * chrome.ui)
                        anchors.verticalCenter: parent.verticalCenter
                        Component.onCompleted: requestPaint()
                        Connections {
                            target: chrome.pal
                            function onNeonChanged()    { headBloom.requestPaint() }
                            function onMagentaChanged() { headBloom.requestPaint() }
                        }
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const c = width / 2, pr = width * 0.32
                            ctx.fillStyle = chrome.goldA(0.9)
                            for (let i = 0; i < 5; i++) {
                                const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                                ctx.beginPath()
                                ctx.ellipse(c + Math.cos(a) * pr - pr * 0.55,
                                            c + Math.sin(a) * pr - pr * 0.55,
                                            pr * 1.1, pr * 1.1)
                                ctx.fill()
                            }
                            ctx.beginPath()
                            ctx.arc(c, c, width * 0.15, 0, Math.PI * 2)
                            ctx.fillStyle = Qt.rgba(chrome.rose.r, chrome.rose.g, chrome.rose.b, 1)
                            ctx.fill()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "golden hour"
                        font.family: chrome.serif
                        font.italic: true
                        font.weight: Font.Medium
                        font.pixelSize: Math.round(14 * chrome.ui)
                        font.letterSpacing: 2
                        color: chrome.gold
                    }

                    // meadow EQ: three grass blades leaning with the bands
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(18 * chrome.ui)
                        height: Math.round(14 * chrome.ui)
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        Repeater {
                            model: [
                                { px: 0,  band: "bass", col: chrome.leaf },
                                { px: 6,  band: "mid",  col: chrome.gold },
                                { px: 12, band: "high", col: chrome.rose }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.px * chrome.ui
                                anchors.bottom: parent.bottom
                                width: Math.round(2 * chrome.ui)
                                radius: width / 2
                                color: modelData.col
                                height: (3 + 11 * Math.min(1, chrome.audio[modelData.band] || 0)) * chrome.ui
                                transformOrigin: Item.Bottom
                                rotation: 8 * Math.min(1, chrome.audio[modelData.band] || 0)
                                Behavior on height { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "in bloom " + chrome.popup.uptimeText.replace("up ", "")
                    font.family: chrome.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(10 * chrome.ui)
                    color: chrome.creamA(0.5)
                }
            }

            // curved stem divider instead of a straight rule
            Canvas {
                id: headRule
                width: parent.width
                height: Math.round(7 * chrome.ui)
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onDimChanged() { headRule.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    ctx.strokeStyle = Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.7)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, height * 0.7)
                    ctx.quadraticCurveTo(width * 0.5, -height * 0.3, width, height * 0.7)
                    ctx.stroke()
                }
            }
        }
    }

    // ── footer: connection roots the card, sign-off on the right ───────────
    readonly property Component footer: Component {
        Column {
            spacing: Math.round(12 * chrome.ui)

            Canvas {
                id: footRule
                width: parent.width
                height: Math.round(7 * chrome.ui)
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onDimChanged() { footRule.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    ctx.strokeStyle = Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.7)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(0, height * 0.3)
                    ctx.quadraticCurveTo(width * 0.5, height * 1.3, width, height * 0.3)
                    ctx.stroke()
                }
            }

            Item {
                width: parent.width
                height: Math.round(13 * chrome.ui)

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(14 * chrome.ui)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(6 * chrome.ui)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(chrome.popup.connType === "ethernet" ? 0xF059F
                            : chrome.popup.connType === "wifi" ? 0xF05A9 : 0xF092F)
                        font.family: chrome.icon
                        font.pixelSize: Math.round(11 * chrome.ui)
                        color: chrome.popup.connType === "none" ? chrome.rose : chrome.leaf
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "still air"
                            : (chrome.popup.connName || "on the breeze")
                        textFormat: Text.PlainText
                        font.family: chrome.serif
                        font.italic: true
                        font.weight: Font.Medium
                        font.pixelSize: Math.round(10 * chrome.ui)
                        color: chrome.popup.connType === "none" ? chrome.rose : chrome.creamA(0.7)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "· grown in the meadow ·"
                    font.family: chrome.serif
                    font.italic: true
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(9 * chrome.ui)
                    font.letterSpacing: 1.5
                    color: chrome.goldA(0.55)
                }
            }
        }
    }

    // ── overlay: a faint golden light-leak across the top edge ─────────────
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                width: parent.width
                height: Math.round(70 * chrome.ui)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.goldA(0.06) }
                    GradientStop { position: 1.0; color: chrome.goldA(0) }
                }
            }
        }
    }
}
