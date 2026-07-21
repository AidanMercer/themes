import QtQuick
import "chalk.js" as Chalk

// homeroom: staff-room notice chrome for the Super+M control popup. The
// shell mounts these pieces around its shared tabs: backdrop (a slate
// notice board — tape tabs, a hand-chalked frame, morning sun pooling in
// from the top, a doodle in the bottom corner), header (halo pip + three
// bunting flags that lift on bass/mid/high + uptime), footer (the
// connection), overlay (a breath of chalk dust on the glass). Item root
// that renders nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function chalkA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function sunA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }
    function pinkA(a)  { return Qt.rgba(pal.magenta.r, pal.magenta.g, pal.magenta.b, a) }

    // the backdrop draws the board; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 6

    // ── backdrop: the notice board ──────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: chrome.glassA(0.95)
                border.width: 1
                border.color: chrome.slateA(0.6)
            }
            // morning sun pooling in from the top
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(110, parent.height * 0.35)
                radius: 6
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.sunA(0.10) }
                    GradientStop { position: 1.0; color: chrome.sunA(0.0) }
                }
            }
            // tape tabs
            Rectangle { x: 26; y: -4; width: 26; height: 10; rotation: -35; color: chrome.chalkA(0.4) }
            Rectangle { x: bd.width - 52; y: -4; width: 26; height: 10; rotation: 32; color: chrome.chalkA(0.4) }

            // the chalked frame
            Canvas {
                id: face
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: chrome.pal
                    function onTextChanged() { face.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height, m = 9
                    Chalk.strokePath(ctx, [[m, m], [w - m, m + 2], [w - m - 2, h - m], [m + 2, h - m - 2], [m, m]], {
                        seed: 501, color: String(chrome.chalkA(1)), alpha: 0.28,
                        width: 2.2, dust: 0.06
                    })
                }
            }

            // the doodle in the corner: a tiny chalk smiley and a star
            Canvas {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 18
                anchors.bottomMargin: 12
                width: 58; height: 26
                opacity: 0.4
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const c = String(chrome.chalkA(1))
                    // smiley
                    Chalk.strokePath(ctx, [[4,10],[8,3],[16,3],[20,10],[18,18],[10,19],[4,13],[4,10]],
                                     { seed: 601, color: c, alpha: 0.8, width: 1.6, dust: 0 })
                    Chalk.strokePath(ctx, [[9,9],[9.5,11]],  { seed: 603, color: c, alpha: 0.9, width: 1.6, ghost: false, dust: 0 })
                    Chalk.strokePath(ctx, [[15,9],[15.5,11]],{ seed: 605, color: c, alpha: 0.9, width: 1.6, ghost: false, dust: 0 })
                    Chalk.strokePath(ctx, [[9,14],[12,15.5],[15,14]], { seed: 607, color: c, alpha: 0.9, width: 1.4, ghost: false, dust: 0 })
                    // star
                    Chalk.strokePath(ctx, [[44,4],[47,12],[55,12],[49,17],[51,24],[44,19],[37,24],[39,17],[33,12],[41,12],[44,4]],
                                     { seed: 611, color: c, alpha: 0.7, width: 1.3, ghost: false, dust: 0 })
                }
                Component.onCompleted: requestPaint()
            }
        }
    }

    // ── header: halo pip + bunting + uptime ────────────────────────────────
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
                        width: 11; height: 11; radius: 5.5
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.9)
                    }
                    // bunting: three little flags lifting on bass / mid / high
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.magenta },
                                { band: "mid",  col: chrome.pal.neon },
                                { band: "high", col: chrome.pal.text }
                            ]
                            delegate: Canvas {
                                id: flag
                                required property var modelData
                                width: 12; height: 16
                                property real lift: Math.min(1, chrome.audio[modelData.band] || 0)
                                onLiftChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    const up = lift * 5
                                    ctx.beginPath()
                                    ctx.moveTo(1, 3 - up * 0.4)
                                    ctx.lineTo(11, 3 - up * 0.4)
                                    ctx.lineTo(6, 14 - up)
                                    ctx.closePath()
                                    ctx.fillStyle = String(Qt.rgba(modelData.col.r, modelData.col.g, modelData.col.b, 0.45 + lift * 0.5))
                                    ctx.fill()
                                }
                                Component.onCompleted: requestPaint()
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

            // a chalk rule under the header
            Canvas {
                id: headRule
                width: parent.width
                height: 6
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[1, 3], [width - 1, 2.4]], {
                        seed: 701, color: String(chrome.chalkA(1)), alpha: 0.35, width: 2, dust: 0.08
                    })
                }
            }
        }
    }

    // ── footer: the connection ──────────────────────────────────────────────
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
                    if (width <= 0) return
                    Chalk.strokePath(ctx, [[1, 2.6], [width - 1, 3]], {
                        seed: 801, color: String(chrome.chalkA(1)), alpha: 0.28, width: 2, dust: 0.06
                    })
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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.chalkA(0.7)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.chalkA(0.7)
                    }
                }
            }
        }
    }

    // ── overlay: a breath of chalk dust on the glass, drawn once ───────────
    readonly property Component overlay: Component {
        Canvas {
            id: dust
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                let s = 12345
                function r() { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff }
                ctx.fillStyle = String(chrome.chalkA(1))
                for (let i = 0; i < 26; i++) {
                    ctx.globalAlpha = 0.03 + r() * 0.05
                    ctx.fillRect(r() * width, r() * height, 1 + r() * 1.6, 1 + r() * 1.6)
                }
            }
        }
    }
}
