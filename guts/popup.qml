import QtQuick

// guts: manga-panel chrome for the Super+M control popup. The card is a
// sharp paper panel with an imperfect hand-ruled double border, screentone
// shading in one corner and a red hanko seal in another. Header carries the
// title caption and a tiny EQ of three slash marks that cut deeper with the
// music; footer is the connection note and a blood-drop sign-off. Red only
// ever appears on live/active elements — everything else is ink on paper.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass…
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color ink:   pal.text
    readonly property color blood: pal.neon
    readonly property color fresh: pal.magenta
    readonly property color paper: pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }

    // the backdrop draws the panel itself — sharp corners, no shell border
    readonly property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.97)
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 0

    // ── backdrop: the manga panel ────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            Canvas {
                id: panelCv
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onTextChanged() { panelCv.requestPaint() }
                    function onNeonChanged() { panelCv.requestPaint() }
                    function onGlassChanged() { panelCv.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    // hand-ruled heavy border
                    ctx.strokeStyle = chrome.inkA(0.92)
                    ctx.lineWidth = 2.5
                    function waver(x0, y0, x1, y1) {
                        ctx.beginPath()
                        ctx.moveTo(x0, y0)
                        const steps = 16
                        for (let i = 1; i <= steps; i++) {
                            const t = i / steps
                            const wob = Math.sin(t * 10 + x0 * 0.07 + y0 * 0.07) * 1.1
                            ctx.lineTo(x0 + (x1 - x0) * t + (y0 === y1 ? 0 : wob),
                                       y0 + (y1 - y0) * t + (y0 === y1 ? wob : 0))
                        }
                        ctx.stroke()
                    }
                    waver(1, 1.5, w - 1, 1.5)
                    waver(w - 1.5, 1, w - 1.5, h - 1)
                    waver(w - 1, h - 1.5, 1, h - 1.5)
                    waver(1.5, h - 1, 1.5, 1)
                    // inner hairline
                    ctx.lineWidth = 1
                    ctx.strokeStyle = chrome.inkA(0.28)
                    ctx.strokeRect(6.5, 6.5, w - 13, h - 13)
                    // screentone shading, bottom-left corner
                    ctx.fillStyle = chrome.inkA(0.12)
                    const rad = Math.min(w, h) * 0.34
                    for (let gy = h - 8; gy > h - rad; gy -= 8) {
                        for (let gx = 8; gx < rad; gx += 8) {
                            const dd = Math.hypot(gx, h - gy) / rad
                            if (dd > 1) continue
                            ctx.beginPath()
                            ctx.arc(gx + (((h - gy) / 8) % 2 ? 4 : 0), gy, 1.8 * (1 - dd), 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                    // the hanko seal, top-right corner — slightly askew
                    ctx.save()
                    ctx.translate(w - 24, 22)
                    ctx.rotate(-0.09)
                    ctx.fillStyle = chrome.blood
                    ctx.beginPath()
                    ctx.moveTo(-8, -9); ctx.lineTo(9, -8); ctx.lineTo(8, 9)
                    ctx.lineTo(-3, 8); ctx.lineTo(-9, 7)
                    ctx.closePath()
                    ctx.fill()
                    // a paper slash through the seal
                    ctx.strokeStyle = Qt.rgba(chrome.paper.r, chrome.paper.g, chrome.paper.b, 0.9)
                    ctx.lineWidth = 2
                    ctx.beginPath(); ctx.moveTo(-5, 5); ctx.lineTo(5, -5); ctx.stroke()
                    ctx.restore()
                }
            }
        }
    }

    // ── header: caption strip ────────────────────────────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 2.5
                        rotation: -32
                        color: chrome.blood
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THE BLACK SWORDSMAN"
                        font.family: chrome.serif
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 4
                        color: chrome.ink
                    }

                    // EQ as three slash marks — they cut deeper with the music
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 14
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.22
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { px: 2,  band: "bass", red: true },
                                { px: 13, band: "mid",  red: false },
                                { px: 24, band: "high", red: false }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.px
                                anchors.verticalCenter: parent.verticalCenter
                                rotation: -34
                                width: 5 + 9 * Math.min(1, chrome.audio[modelData.band] || 0)
                                height: 2.5
                                color: modelData.red ? chrome.fresh : chrome.ink
                                Behavior on width { NumberAnimation { duration: 80 } }
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
                        text: "fol. CTRL"
                        font.family: chrome.serif
                        font.italic: true
                        font.pixelSize: 10
                        color: chrome.inkA(0.5)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "awake " + chrome.popup.uptimeText.replace("up ", "")
                        font.family: chrome.serif
                        font.italic: true
                        font.pixelSize: 10
                        color: chrome.inkA(0.5)
                    }
                }
            }

            Rectangle { width: parent.width; height: 1.5; color: chrome.inkA(0.75) }
        }
    }

    // ── footer: the margin note ──────────────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle { width: parent.width; height: 1.5; color: chrome.inkA(0.75) }

            Item {
                width: parent.width
                height: 14

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String.fromCodePoint(chrome.popup.connType === "ethernet" ? 0xF059F
                            : chrome.popup.connType === "wifi" ? 0xF05A9 : 0xF092F)
                        font.family: chrome.icon
                        font.pixelSize: 11
                        color: chrome.popup.connType === "none" ? chrome.fresh : chrome.inkA(0.7)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "severed"
                            : (chrome.popup.connName || "connected")
                        font.family: chrome.serif
                        font.italic: true
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.fresh : chrome.inkA(0.7)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "// the brand of sacrifice"
                        font.family: chrome.serif
                        font.pixelSize: 9
                        color: Qt.rgba(chrome.blood.r, chrome.blood.g, chrome.blood.b, 0.75)
                    }
                    // a drop of blood, slowly welling
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 7; radius: 2.5
                        color: chrome.fresh
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    // ── overlay: paper grain, no input ───────────────────────────────────────
    readonly property Component overlay: Component {
        Canvas {
            id: grain
            opacity: 0.5
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                // deterministic flecks of paper grain + one stray ink speck
                ctx.fillStyle = chrome.inkA(0.10)
                let sd = 7
                function r() { sd = (sd * 16807) % 2147483647; return sd / 2147483647 }
                const n = Math.round(width * height / 4200)
                for (let i = 0; i < n; i++) {
                    ctx.beginPath()
                    ctx.arc(r() * width, r() * height, 0.4 + r() * 0.8, 0, Math.PI * 2)
                    ctx.fill()
                }
                ctx.fillStyle = Qt.rgba(chrome.blood.r, chrome.blood.g, chrome.blood.b, 0.30)
                ctx.beginPath()
                ctx.arc(width * 0.12, height * 0.82, 1.6, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}
