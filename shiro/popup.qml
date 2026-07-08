import QtQuick

// shiro: washi chrome for the Super+M control popup. The card becomes a sheet
// of near-white paper with an ink hairline; a wisteria brush stroke runs down
// the left edge, a faint enso watermark sits behind the content and a blush
// hanko seal stamps the corner. Header is the theme's spaced lowercase voice
// with three ink droplets breathing to the music; footer signs the sheet.
// Item root (Loader refuses QtObject); renders nothing itself — the shell
// mounts the Components below around its shared tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color ink:      pal.text
    readonly property color wisteria: pal.neon
    readonly property color blush:    pal.cyan
    readonly property color rose:     pal.magenta
    readonly property string sans:    "Noto Sans"
    readonly property string serif:   "Noto Serif Display"
    function inkA(a) { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function toWhite(c, t) {
        return Qt.rgba(c.r + (1 - c.r) * t, c.g + (1 - c.g) * t, c.b + (1 - c.b) * t, 1)
    }
    readonly property color paper: toWhite(pal.glass, 0.65)

    readonly property color cardBg: Qt.rgba(paper.r, paper.g, paper.b, 0.97)
    readonly property color cardBorder: inkA(0.16)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 6

    // ── backdrop: brush spine, enso watermark, hanko seal ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // tapered wisteria brush stroke down the left edge — the
            // notification cards' gesture, scaled up to the sheet
            Canvas {
                id: spine
                width: 12
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 6 }
                onHeightChanged: requestPaint()
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { spine.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const h = height
                    if (h <= 0) return
                    const c = chrome.wisteria
                    ctx.beginPath()
                    ctx.moveTo(2, 0)
                    for (let y = 0; y <= h; y += 4) {
                        const t = Math.min(1, y / h)
                        const w = 1.0 + 3.6 * Math.pow(1 - t, 1.4) + Math.sin(t * 8 + 1) * 0.5
                        ctx.lineTo(2 + Math.max(0.8, w), y)
                    }
                    ctx.lineTo(2, h)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.55)
                    ctx.fill()
                    // the flick where the brush landed
                    ctx.beginPath()
                    ctx.arc(9.5, 6, 1.4, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.35)
                    ctx.fill()
                }
            }

            // faint enso watermark behind the lower-right of the content
            Canvas {
                id: enso
                width: 150; height: 150
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 8 }
                Connections {
                    target: chrome.pal
                    function onTextChanged() { enso.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2, cy = height / 2, r = 62
                    // an open circle, heavier where the brush pressed
                    ctx.lineCap = "round"
                    const start = -Math.PI * 0.42, sweep = Math.PI * 1.78
                    const steps = 40
                    for (let i = 0; i < steps; i++) {
                        const t = i / steps
                        const a0 = start + sweep * t
                        const a1 = start + sweep * (t + 1 / steps)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, a0, a1)
                        ctx.lineWidth = 2 + 5 * Math.sin(t * Math.PI) * (1 - t * 0.4)
                        ctx.strokeStyle = chrome.inkA(0.055)
                        ctx.stroke()
                    }
                }
            }

            // blush hanko seal, bottom-right — same stamp as the notif cards
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                width: 11; height: 11; radius: 2
                color: "transparent"
                border.width: 1
                border.color: chrome.blush
                opacity: 0.4
                Rectangle {
                    anchors.centerIn: parent
                    width: 3; height: 3; radius: 1
                    color: chrome.blush
                }
            }
        }
    }

    // ── header: breathing blush dot + c o n t r o l + ink droplets, uptime ──
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: chrome.blush
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 2100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2100; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "c o n t r o l"
                        color: chrome.inkA(0.60)
                        font.family: chrome.sans
                        font.pixelSize: 11
                        font.letterSpacing: 4
                    }

                    // three ink droplets that swell with the music, dry when quiet
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 0.9 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.wisteria },
                                { band: "mid",  col: chrome.blush },
                                { band: "high", col: chrome.ink }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3 + 4 * Math.min(1, chrome.audio[modelData.band] || 0)
                                height: width
                                radius: width / 2
                                color: modelData.col
                                Behavior on width { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "up " + chrome.popup.uptimeText.replace("up ", "")
                    color: chrome.inkA(0.45)
                    font.family: chrome.serif
                    font.pixelSize: 11
                    font.italic: true
                }
            }

            // hairline with the clock's slow-drifting wisteria segment
            Item {
                width: parent.width
                height: 2

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 1
                    color: chrome.inkA(0.14)
                }
                Rectangle {
                    id: drift
                    width: 44; height: 2; radius: 1
                    color: chrome.wisteria
                    opacity: 0.8
                    SequentialAnimation on x {
                        running: chrome.popup.open
                        loops: Animation.Infinite
                        NumberAnimation { to: drift.parent.width - 44; duration: 9000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 9000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ── footer: connection, signed shiro ──
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.inkA(0.14)
            }

            Item {
                width: parent.width
                height: 14

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4; height: 4; radius: 2
                        color: chrome.popup.connType === "none" ? chrome.rose : chrome.wisteria
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online").toLowerCase()
                        textFormat: Text.PlainText
                        color: chrome.inkA(0.55)
                        font.family: chrome.sans
                        font.pixelSize: 10
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 18   // clear the hanko seal
                    anchors.verticalCenter: parent.verticalCenter
                    text: "— shiro"
                    color: chrome.blush
                    font.family: chrome.serif
                    font.pixelSize: 11
                    font.italic: true
                    opacity: 0.75
                }
            }
        }
    }
}
