import QtQuick

// road8: pause-menu chrome for the Super+M control popup. The shell mounts
// these pieces around its shared tabs: backdrop (a pixel-cut dialog face —
// night glass, amber frame, headlight glow leaking down from the top, a
// tiny 8-bit car parked in the bottom corner), header (CHECK lamp blinking
// in hard steps + a three-tower block equalizer riding the music in
// whole-window jumps + uptime), footer (net + the chevron ticker),
// overlay (faint CRT scanlines down the glass). Item root that renders
// nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    // the backdrop draws the dialog face; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 4

    // ── backdrop: the pause dialog ──────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: face
                anchors.fill: parent
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
                    const w = width, h = height, s = 7
                    ctx.beginPath()
                    ctx.moveTo(s, 0.5)
                    ctx.lineTo(w - s, 0.5)
                    ctx.lineTo(w - s, s); ctx.lineTo(w - 0.5, s)
                    ctx.lineTo(w - 0.5, h - s); ctx.lineTo(w - s, h - s)
                    ctx.lineTo(w - s, h - 0.5); ctx.lineTo(s, h - 0.5)
                    ctx.lineTo(s, h - s); ctx.lineTo(0.5, h - s)
                    ctx.lineTo(0.5, s); ctx.lineTo(s, s)
                    ctx.closePath()
                    ctx.fillStyle = String(chrome.glassA(0.95))
                    ctx.fill()
                    ctx.strokeStyle = String(chrome.amberA(0.55))
                    ctx.lineWidth = 1.5
                    ctx.stroke()
                    // headlight glow leaking down from the header
                    const g = ctx.createLinearGradient(0, 0, 0, Math.min(120, h * 0.4))
                    g.addColorStop(0, String(chrome.amberA(0.11)))
                    g.addColorStop(1, String(chrome.amberA(0)))
                    ctx.fillStyle = g
                    ctx.fillRect(2, 1, w - 4, Math.min(120, h * 0.4))
                }
            }

            // the little car, parked in the bottom-right of the face
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 16
                anchors.bottomMargin: 12
                width: 22; height: 10
                opacity: 0.5
                Rectangle { x: 1; y: 4; width: 20; height: 4; color: chrome.slateA(1) }
                Rectangle { x: 6; y: 1; width: 10; height: 3; color: chrome.slateA(1) }
                Rectangle { x: 4; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
                Rectangle { x: 15; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
                Rectangle { x: 0; y: 4; width: 2; height: 3; color: chrome.pal.magenta }
                Rectangle { x: 20; y: 4; width: 2; height: 3; color: chrome.pal.neon }
            }
        }
    }

    // ── header: CHECK lamp + block EQ + uptime ──────────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Rectangle {
                        id: lamp
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7
                        property bool tick: true
                        color: tick ? chrome.pal.neon : chrome.amberA(0.25)
                        Timer {
                            interval: 800; repeat: true
                            running: chrome.popup.open
                            onTriggered: lamp.tick = !lamp.tick
                        }
                    }
                    // three towers of window-blocks, lighting floor by floor
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.neon },
                                { band: "mid",  col: chrome.pal.cyan },
                                { band: "high", col: chrome.pal.text }
                            ]
                            delegate: Column {
                                id: tower
                                required property var modelData
                                readonly property int lit: Math.min(5, Math.ceil((chrome.audio[modelData.band] || 0) * 5))
                                spacing: 1
                                anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: 5
                                    Rectangle {
                                        required property int index
                                        width: 5; height: 2
                                        // fills bottom-up in whole blocks, no glide
                                        color: (4 - index) < tower.lit ? tower.modelData.col : chrome.slateA(0.5)
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: chrome.popup.uptimeText
                    font.family: chrome.mono
                    font.pixelSize: 10
                    color: chrome.slateA(1.0)
                }
            }

            // the center line, dashed across the dialog
            Item {
                id: headRule
                width: parent.width
                height: 2
                Row {
                    spacing: 10
                    Repeater {
                        model: Math.max(3, Math.floor((headRule.width + 10) / 26))
                        Rectangle {
                            width: 16; height: 2
                            color: chrome.amberA(0.45)
                        }
                    }
                }
            }
        }
    }

    // ── footer: net + the chevron ticker ────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Item {
                id: footRule
                width: parent.width
                height: 2
                Row {
                    spacing: 10
                    Repeater {
                        model: Math.max(3, Math.floor((footRule.width + 10) / 26))
                        Rectangle {
                            width: 16; height: 2
                            color: chrome.slateA(0.6)
                        }
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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "OFFLINE"
                            : (chrome.popup.connName || "ONLINE")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.inkA(0.75)
                    }
                }

                Text {
                    id: chevrons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    property int step: 0
                    text: step === 0 ? "▸  " : step === 1 ? "▸▸ " : "▸▸▸"
                    font.family: chrome.mono
                    font.pixelSize: 9
                    color: chrome.pal.neon
                    Timer {
                        interval: 500; repeat: true
                        running: chrome.popup.open
                        onTriggered: chevrons.step = (chevrons.step + 1) % 3
                    }
                }
            }
        }
    }

    // ── overlay: faint CRT scanlines down the dialog glass ──────────────────
    readonly property Component overlay: Component {
        Canvas {
            id: scan
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                ctx.fillStyle = "rgba(0,0,0,0.05)"
                for (let y = 2; y < height - 2; y += 3)
                    ctx.fillRect(2, y, width - 4, 1)
            }
        }
    }
}
