import QtQuick

// downpour: breath-fog chrome for the Super+M control menu. The shell mounts
// these pieces around its shared tabs: backdrop (a condensation pane —
// wobbled corners, a pale breath pooling in the middle, beads gathered on
// the lower rim), header (a listening bead + three beads that swell with
// the music + uptime), footer (the connection + one patient drip), overlay
// (two still beads in the corners). Item root that renders nothing itself;
// no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string serif: "Noto Serif"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function paneA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }
    function rnd(n) {
        let x = Math.imul(n ^ 0x9e3779b9, 0x85ebca6b)
        x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16
        return (x >>> 0) / 4294967296
    }

    // the backdrop draws the pane; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 22

    // ── backdrop: the condensation pane ─────────────────────────────────────
    readonly property Component backdrop: Component {
        Canvas {
            id: face
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: chrome.pal
                function onNeonChanged() { face.requestPaint() }
                function onGlassChanged() { face.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const w = width, h = height
                const r = [24, 32, 26, 36].map((v, i) => v * (0.8 + 0.5 * chrome.rnd(i * 19 + 3)))
                ctx.beginPath()
                ctx.moveTo(r[0], 1)
                ctx.lineTo(w - r[1], 1); ctx.quadraticCurveTo(w - 1, 1, w - 1, r[1])
                ctx.lineTo(w - 1, h - r[2]); ctx.quadraticCurveTo(w - 1, h - 1, w - r[2], h - 1)
                ctx.lineTo(r[3], h - 1); ctx.quadraticCurveTo(1, h - 1, 1, h - r[3])
                ctx.lineTo(1, r[0]); ctx.quadraticCurveTo(1, 1, r[0], 1)
                ctx.closePath()
                ctx.fillStyle = String(chrome.glassA(0.94))
                ctx.fill()
                ctx.strokeStyle = String(chrome.inkA(0.13))
                ctx.lineWidth = 1.4
                ctx.stroke()
                // the breath pooling in the middle
                const g = ctx.createRadialGradient(w * 0.5, h * 0.35, 0, w * 0.5, h * 0.35, w * 0.6)
                g.addColorStop(0, String(chrome.inkA(0.045)))
                g.addColorStop(1, String(chrome.inkA(0)))
                ctx.fillStyle = g
                ctx.fill()
                // beads gathered on the lower rim
                for (let i = 0; i < 5; i++) {
                    const bx = w * (0.12 + 0.18 * i + 0.05 * chrome.rnd(i * 43 + 11))
                    const bs = 2.6 + 2.6 * chrome.rnd(i * 7 + 2)
                    ctx.beginPath()
                    ctx.ellipse(bx, h - 4 - bs, bs, bs * 1.25)
                    ctx.fillStyle = String(chrome.paneA(0.38))
                    ctx.fill()
                }
            }
        }
    }

    // ── header: bead + three swelling beads + uptime ────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 10

            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 10
                        radius: 4
                        color: chrome.paneA(0.85)
                        Rectangle { x: 1.6; y: 1.8; width: 2.2; height: 2.2; radius: 1.1; color: chrome.inkA(0.85) }
                    }
                    // three beads hanging from a tiny rail, swelling with the music
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34; height: 22
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.28
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                        Rectangle { y: 3; width: 34; height: 1; color: chrome.slateA(0.9) }
                        Repeater {
                            model: [
                                { band: "bass", cx: 5 },
                                { band: "mid",  cx: 16 },
                                { band: "high", cx: 27 }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property real v: Math.min(1, chrome.audio[modelData.band] || 0)
                                x: modelData.cx
                                y: 4
                                width: 5
                                height: 4 + v * 13
                                radius: 2.5
                                color: chrome.paneA(0.35 + v * 0.5)
                                Behavior on height { NumberAnimation { duration: 120 } }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: chrome.popup.uptimeText
                    font.family: chrome.serif
                    font.italic: true
                    font.pixelSize: 11
                    color: chrome.slateA(1.0)
                }
            }

            // a sagging waterline instead of a rule
            Canvas {
                id: headRule
                width: parent.width
                height: 6
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(0, 2)
                    ctx.quadraticCurveTo(w * 0.3, 4.5, w * 0.6, 2.8)
                    ctx.quadraticCurveTo(w * 0.85, 1.6, w, 3.4)
                    ctx.strokeStyle = String(chrome.paneA(0.30))
                    ctx.lineWidth = 1.1
                    ctx.stroke()
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── footer: the connection + one patient drip ───────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 10

            Canvas {
                id: footRule
                width: parent.width
                height: 6
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(0, 3.5)
                    ctx.quadraticCurveTo(w * 0.35, 1.6, w * 0.65, 3.2)
                    ctx.quadraticCurveTo(w * 0.85, 4.4, w, 2.4)
                    ctx.strokeStyle = String(chrome.slateA(0.7))
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
                Component.onCompleted: requestPaint()
            }

            Item {
                width: parent.width
                height: 16

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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.paneA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "connected")
                        textFormat: Text.PlainText
                        font.family: chrome.serif
                        font.italic: true
                        font.pixelSize: 11
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.inkA(0.65)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    // the patient drip: a bead slides its 10px and rests
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 16
                        Rectangle {
                            id: drip
                            x: 0.8
                            width: 4.4; height: 5.6
                            radius: 2.2
                            color: chrome.paneA(0.8)
                            property real t: 0
                            y: t * 10
                            opacity: 1 - t * 0.6
                            SequentialAnimation {
                                running: chrome.popup.open
                                loops: Animation.Infinite
                                PauseAnimation { duration: 3400 }
                                NumberAnimation { target: drip; property: "t"; from: 0; to: 1; duration: 600; easing.type: Easing.InQuad }
                                PauseAnimation { duration: 200 }
                                PropertyAction { target: drip; property: "t"; value: 0 }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── overlay: two still beads keeping to the corners ─────────────────────
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                x: 14; y: 12
                width: 5; height: 6.4
                radius: 2.5
                color: chrome.paneA(0.35)
                Rectangle { x: 1; y: 1.2; width: 1.5; height: 1.5; radius: 0.8; color: chrome.inkA(0.6) }
            }
            Rectangle {
                x: parent.width - 22; y: parent.height - 20
                width: 4; height: 5.2
                radius: 2
                color: chrome.paneA(0.28)
            }
        }
    }
}
