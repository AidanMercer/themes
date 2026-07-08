import QtQuick

// avalon: chrome for the Super+M control popup — moss glass card, gold
// hairline border, a blossom watermark in the corner. Item root that renders
// nothing itself; the shell mounts the Components below around its tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color ivory: pal.text
    readonly property color leaf:  pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color moss:  pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function ivoryA(a) { return Qt.rgba(ivory.r, ivory.g, ivory.b, a) }
    function goldA(a)  { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    readonly property color cardBg: Qt.rgba(moss.r, moss.g, moss.b, 0.88)
    readonly property color cardBorder: goldA(0.32)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    // ── backdrop: inner gold hairline + a blossom watermark ──
    readonly property Component backdrop: Component {
        Canvas {
            id: bd
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: chrome.pal
                function onCyanChanged() { bd.requestPaint() }
                function onTextChanged() { bd.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height

                ctx.strokeStyle = chrome.goldA(0.14)
                ctx.lineWidth = 1
                ctx.strokeRect(6.5, 6.5, w - 13, h - 13)

                // blossom watermark, bottom-right
                const cx = w - 46, cy = h - 46, pr = 26
                ctx.strokeStyle = chrome.goldA(0.10)
                ctx.lineWidth = 1.2
                for (let i = 0; i < 5; i++) {
                    const a = -Math.PI / 2 + i * Math.PI * 2 / 5
                    ctx.save()
                    ctx.translate(cx + Math.cos(a) * pr * 0.72, cy + Math.sin(a) * pr * 0.72)
                    ctx.rotate(a + Math.PI / 2)
                    ctx.scale(pr * 0.34, pr * 0.60)
                    ctx.beginPath()
                    ctx.arc(0, 0, 1, 0, Math.PI * 2)
                    ctx.restore()
                    ctx.stroke()
                }
                ctx.beginPath()
                ctx.arc(cx, cy, 4, 0, Math.PI * 2)
                ctx.stroke()
            }
        }
    }

    // ── header: blossom pip + AVALON + a soft EQ, uptime on the right ──
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
                        width: 6; height: 6
                        rotation: 45
                        color: chrome.leaf
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "avalon"
                        font.family: chrome.serif
                        font.pixelSize: 14
                        font.letterSpacing: 6
                        font.italic: true
                        color: chrome.ivory
                    }

                    // quiet EQ — sways while something plays, rests when silent
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 11
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 0.9 : 0.2
                        Behavior on opacity { NumberAnimation { duration: 220 } }

                        Repeater {
                            model: [
                                { px: 0,  band: "bass", col: chrome.gold },
                                { px: 5,  band: "mid",  col: chrome.ivory },
                                { px: 10, band: "high", col: chrome.leaf }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.px
                                width: 3
                                anchors.bottom: parent.bottom
                                color: modelData.col
                                height: 2 + 9 * Math.min(1, chrome.audio[modelData.band] || 0)
                                Behavior on height { NumberAnimation { duration: 80 } }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "up " + chrome.popup.uptimeText.replace("up ", "")
                    font.family: chrome.pal.fontMono
                    font.pixelSize: 10
                    color: chrome.goldA(0.55)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.goldA(0.25)
            }
        }
    }

    // ── footer: connection on the left, the shrine's whisper on the right ──
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.goldA(0.25)
            }

            Item {
                width: parent.width
                height: 13

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
                        color: chrome.popup.connType === "none" ? chrome.rose : chrome.leaf
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        textFormat: Text.PlainText
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        color: chrome.ivoryA(0.55)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "where the small gods sleep"
                    font.family: chrome.serif
                    font.pixelSize: 9
                    font.italic: true
                    font.letterSpacing: 2
                    color: chrome.goldA(0.50)
                }
            }
        }
    }
}
