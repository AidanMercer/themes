import QtQuick

// lonely-train: cassette-case chrome for the Super+M control popup.
// The shell mounts these pieces around its shared tabs: backdrop (the
// cassette label — corner screws, amber label band, route line along the
// bottom), header (REC pip + LONELY TRAIN + live EQ // SIDE A + REEL
// uptime), footer (NET + a serif sign-off with a red tape pip), overlay
// (a whisper of film grain). Invisible Item root; renders nothing itself.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function duskA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.94)
    readonly property color cardBorder: amberA(0.45)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    // ── backdrop: the cassette label ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: label
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                // pal reads config.toml async — retint if it lands after paint
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { label.requestPaint() }
                    function onCyanChanged() { label.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height
                    ctx.reset()
                    // label band under the header area
                    ctx.fillStyle = Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.05)
                    ctx.fillRect(1, 1, w - 2, 52)
                    ctx.beginPath()
                    ctx.moveTo(10, 53); ctx.lineTo(w - 10, 53)
                    ctx.strokeStyle = Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.3)
                    ctx.lineWidth = 1
                    ctx.stroke()
                    // corner screws
                    for (const [sx, sy] of [[12, 12], [w - 12, 12], [12, h - 12], [w - 12, h - 12]]) {
                        ctx.beginPath()
                        ctx.arc(sx, sy, 2.6, 0, Math.PI * 2)
                        ctx.strokeStyle = Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.5)
                        ctx.lineWidth = 1.2
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(sx - 1.6, sy); ctx.lineTo(sx + 1.6, sy)
                        ctx.stroke()
                    }
                    // route line along the bottom, five stations, mid-dot lit
                    const ry = h - 12, rx0 = w * 0.3, rx1 = w * 0.7
                    ctx.beginPath()
                    ctx.moveTo(rx0, ry); ctx.lineTo(rx1, ry)
                    ctx.strokeStyle = Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.4)
                    ctx.lineWidth = 1.4
                    ctx.stroke()
                    for (let i = 0; i < 5; i++) {
                        const x = rx0 + (rx1 - rx0) * i / 4
                        ctx.beginPath()
                        ctx.arc(x, ry, i === 2 ? 3.2 : 2.2, 0, Math.PI * 2)
                        if (i === 2) {
                            ctx.fillStyle = chrome.pal.neon
                            ctx.fill()
                        } else {
                            ctx.strokeStyle = Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.55)
                            ctx.lineWidth = 1.2
                            ctx.stroke()
                        }
                    }
                }
            }
        }
    }

    // ── header: REC pip + LONELY TRAIN + EQ // SIDE A + REEL uptime ──
    readonly property Component header: Component {
        Column {
            spacing: 14

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: chrome.pal.magenta
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8
                        color: "transparent"
                        border.width: 1.6
                        border.color: chrome.pal.neon
                        Text {
                            anchors.centerIn: parent
                            text: "LT"
                            color: chrome.pal.neon
                            font.family: chrome.mono
                            font.pixelSize: 6
                            font.weight: Font.Black
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LONELY TRAIN"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 4
                        color: chrome.pal.neon
                    }

                    // live EQ off the shell's cava — still and dim when quiet
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 12
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        Repeater {
                            model: [
                                { px: 0,  band: "bass", col: chrome.pal.magenta },
                                { px: 5,  band: "mid",  col: chrome.pal.neon },
                                { px: 10, band: "high", col: chrome.pal.cyan }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.px
                                width: 3
                                anchors.bottom: parent.bottom
                                color: modelData.col
                                height: 2 + 10 * Math.min(1, chrome.audio[modelData.band] || 0)
                                Behavior on height { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SIDE A · CTRL"
                        font.family: chrome.mono
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        color: chrome.duskA(0.75)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REEL " + chrome.popup.uptimeText.replace("up ", "").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: chrome.inkA(0.4)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.inkA(0.10)
            }
        }
    }

    // ── footer: NET (left) + serif sign-off with tape pip (right) ──
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.inkA(0.10)
            }

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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.duskA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "OFFLINE"
                            : (chrome.popup.connName || "ONLINE")
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.duskA(0.9)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "last train home"
                        font.family: chrome.serif
                        font.pixelSize: 10
                        font.italic: true
                        font.letterSpacing: 2
                        color: chrome.inkA(0.4)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: chrome.pal.magenta
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 900 }
                            NumberAnimation { to: 0.9; duration: 900 }
                        }
                    }
                }
            }
        }
    }

    // ── overlay: a whisper of static film grain, no input grabbing ──
    readonly property Component overlay: Component {
        Canvas {
            opacity: 0.5
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const n = Math.floor(width * height / 900)
                for (let i = 0; i < n; i++) {
                    const x = Math.random() * width
                    const y = Math.random() * height
                    const a = 0.015 + Math.random() * 0.04
                    ctx.fillStyle = Math.random() < 0.5
                        ? "rgba(255,255,255," + a + ")"
                        : "rgba(0,0,0," + (a * 1.6) + ")"
                    ctx.fillRect(x, y, 1, 1)
                }
            }
        }
    }
}
