import QtQuick

// vinland: chrome for the Super+M control popup — night glass card with an
// ice hairline, a compass-star watermark in the corner, and thorfinn's creed
// in the footer. Item root that renders nothing itself; the shell mounts the
// Components below around its tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color snow:  pal.text
    readonly property color ice:   pal.neon
    readonly property color gold:  pal.cyan
    readonly property color rose:  pal.magenta
    readonly property color night: pal.glass
    readonly property string serif: "Noto Serif Display"
    readonly property string icon: "Symbols Nerd Font"
    function snowA(a) { return Qt.rgba(snow.r, snow.g, snow.b, a) }
    function iceA(a)  { return Qt.rgba(ice.r, ice.g, ice.b, a) }
    function goldA(a) { return Qt.rgba(gold.r, gold.g, gold.b, a) }

    readonly property color cardBg: Qt.rgba(night.r, night.g, night.b, 0.90)
    readonly property color cardBorder: iceA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 12

    // ── backdrop: inner ice hairline + a compass-star watermark ──
    readonly property Component backdrop: Component {
        Canvas {
            id: bd
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            Connections {
                target: chrome.pal
                function onNeonChanged() { bd.requestPaint() }
                function onCyanChanged() { bd.requestPaint() }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width, h = height

                ctx.strokeStyle = chrome.iceA(0.12)
                ctx.lineWidth = 1
                ctx.strokeRect(6.5, 6.5, w - 13, h - 13)

                // compass star watermark, bottom-right: a thin four-point star
                // inside a notched bearing ring
                const cx = w - 48, cy = h - 48, R = 26
                ctx.strokeStyle = chrome.iceA(0.11)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.arc(cx, cy, R, 0, Math.PI * 2)
                ctx.stroke()
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4
                    const r1 = i % 2 === 0 ? R - 5 : R - 3
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)
                    ctx.lineTo(cx + Math.cos(a) * R, cy + Math.sin(a) * R)
                    ctx.stroke()
                }
                const sR = R * 0.62
                ctx.beginPath()
                ctx.moveTo(cx, cy - sR)
                ctx.quadraticCurveTo(cx, cy, cx + sR, cy)
                ctx.quadraticCurveTo(cx, cy, cx, cy + sR)
                ctx.quadraticCurveTo(cx, cy, cx - sR, cy)
                ctx.quadraticCurveTo(cx, cy, cx, cy - sR)
                ctx.closePath()
                ctx.stroke()
                // north is the gold point
                ctx.fillStyle = chrome.goldA(0.35)
                ctx.beginPath()
                ctx.arc(cx, cy - R, 1.6, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    // ── header: gold star pip + vinland + a soft EQ, uptime on the right ──
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

                    Canvas {
                        id: pip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9; height: 9
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const c = width / 2, R = width / 2
                            ctx.beginPath()
                            ctx.moveTo(c, c - R)
                            ctx.quadraticCurveTo(c, c, c + R, c)
                            ctx.quadraticCurveTo(c, c, c, c + R)
                            ctx.quadraticCurveTo(c, c, c - R, c)
                            ctx.quadraticCurveTo(c, c, c, c - R)
                            ctx.closePath()
                            ctx.fillStyle = Qt.rgba(chrome.gold.r, chrome.gold.g, chrome.gold.b, 0.95)
                            ctx.fill()
                        }
                        Connections {
                            target: chrome.pal
                            function onCyanChanged() { pip.requestPaint() }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "vinland"
                        font.family: chrome.serif
                        font.pixelSize: 14
                        font.letterSpacing: 6
                        font.italic: true
                        font.weight: Font.Medium
                        color: chrome.snow
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
                                { px: 5,  band: "mid",  col: chrome.snow },
                                { px: 10, band: "high", col: chrome.ice }
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
                    color: chrome.iceA(0.55)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.iceA(0.22)
            }
        }
    }

    // ── footer: connection on the left, the creed on the right ──
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.iceA(0.22)
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
                        color: chrome.popup.connType === "none" ? chrome.rose : chrome.ice
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        font.family: "Noto Sans"
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        font.letterSpacing: 1
                        color: chrome.snowA(0.55)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "i have no enemies."
                    font.family: chrome.serif
                    font.pixelSize: 9
                    font.italic: true
                    font.weight: Font.Medium
                    font.letterSpacing: 2
                    color: chrome.goldA(0.55)
                }
            }
        }
    }
}
