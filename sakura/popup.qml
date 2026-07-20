import QtQuick

// sakura: hanami chrome for the Super+M control menu. Dusk-plum card with a
// twig drawn across the top edge carrying three small blossoms — the middle
// trio doubles as a live EQ, each flower opening with its band while music
// plays (law 1). Header speaks the theme's voice; footer carries the net
// status and the sign-off. Item root; the shell mounts the pieces around its
// shared tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property color pink:  pal.neon
    readonly property color sky:   pal.cyan
    readonly property color cream: pal.text
    readonly property color plum:  pal.glass
    readonly property string sans: "Noto Sans"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function creamA(a) { return Qt.rgba(cream.r, cream.g, cream.b, a) }
    function pinkA(a)  { return Qt.rgba(pink.r, pink.g, pink.b, a) }
    function twigA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    readonly property color cardBg: Qt.rgba(plum.r, plum.g, plum.b, 0.93)
    readonly property color cardBorder: pinkA(0.34)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 16

    // the blossom painter (bud 0 → bloom 1)
    function drawBlossom(ctx, r, bloom, fillCol, coreCol) {
        if (bloom < 0.1) {
            ctx.beginPath()
            ctx.arc(0, 0, Math.max(1, r * 0.30), 0, 2 * Math.PI)
            ctx.fillStyle = fillCol
            ctx.fill()
            return
        }
        const pr = r * (0.4 + 0.6 * bloom)
        const w = pr * 0.55 * (0.55 + 0.45 * bloom)
        for (let i = 0; i < 5; i++) {
            ctx.save()
            ctx.rotate(i * Math.PI * 2 / 5)
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.bezierCurveTo(-w, -pr * 0.35, -w * 0.9, -pr * 0.85, -pr * 0.16, -pr * 0.97)
            ctx.lineTo(0, -pr * 0.85)
            ctx.lineTo(pr * 0.16, -pr * 0.97)
            ctx.bezierCurveTo(w * 0.9, -pr * 0.85, w, -pr * 0.35, 0, 0)
            ctx.closePath()
            ctx.fillStyle = fillCol
            ctx.fill()
            ctx.restore()
        }
        ctx.beginPath()
        ctx.arc(0, 0, Math.max(0.8, r * 0.14), 0, 2 * Math.PI)
        ctx.fillStyle = coreCol
        ctx.fill()
    }

    // ── backdrop: canopy light + a twig along the top edge ──────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // warm light leaking from the canopy above
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 64
                radius: chrome.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.pinkA(0.10) }
                    GradientStop { position: 1.0; color: chrome.pinkA(0.0) }
                }
            }

            // the twig lying across the top, dipping slightly mid-card
            Canvas {
                id: twigLine
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 26
                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width
                    ctx.beginPath()
                    ctx.moveTo(14, 12)
                    ctx.bezierCurveTo(w * 0.3, 18, w * 0.7, 8, w - 14, 14)
                    ctx.strokeStyle = String(chrome.twigA(0.85))
                    ctx.lineWidth = 1.6
                    ctx.stroke()
                }
                Connections {
                    target: chrome.pal
                    function onDimChanged() { twigLine.requestPaint() }
                }
            }
        }
    }

    // ── header: blossom pip + hanami + the blossom EQ, uptime right ─────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "hanami"
                        font.family: chrome.sans
                        font.pixelSize: 14
                        font.letterSpacing: 4
                        color: chrome.creamA(0.95)
                    }

                    // three blossoms as a live EQ — bass, mid, high
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pink },
                                { band: "mid",  col: chrome.pinkA(0.85) },
                                { band: "high", col: chrome.sky }
                            ]
                            delegate: Canvas {
                                id: eqB
                                required property var modelData
                                width: 14; height: 14
                                readonly property real lvl: Math.min(1, chrome.audio[modelData.band] || 0)
                                onLvlChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.translate(width / 2, height / 2)
                                    chrome.drawBlossom(ctx, 6.5, eqB.lvl,
                                        String(Qt.rgba(modelData.col.r, modelData.col.g, modelData.col.b, 0.4 + eqB.lvl * 0.55)),
                                        String(chrome.creamA(0.7)))
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "held " + chrome.popup.uptimeText.replace("up ", "")
                    font.family: chrome.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: chrome.creamA(0.6)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.twigA(0.6)
            }
        }
    }

    // ── footer: net status + sign-off ───────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.twigA(0.6)
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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.sky
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "off the wind"
                            : (chrome.popup.connName || "on the wind")
                        textFormat: Text.PlainText
                        font.family: chrome.sans
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.creamA(0.7)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "❀ under the canopy"
                    font.family: chrome.sans
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: chrome.pinkA(0.6)
                }
            }
        }
    }
}
