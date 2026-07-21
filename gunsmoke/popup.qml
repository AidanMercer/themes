import QtQuick

// gunsmoke: ledger chrome for the Super+M control popup. The shell mounts
// the pieces around its shared tabs: backdrop (an iron-dark slip with double
// ledger rules and corner rivets), header (a three-lantern fog EQ + uptime),
// footer (the connection's state), overlay (faint ledger ruling across the
// card — paper, not scanlines). Invisible Item root; renders nothing itself.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    // the backdrop draws its own paper + edges; the card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 0

    readonly property string serif: "Noto Serif"
    readonly property string mono: pal.fontMono
    function boneA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function ashA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }

    // ── backdrop: the slip ──────────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: paper
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                // pal reads config.toml async — retint if it lands after first paint
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { paper.requestPaint() }
                    function onDimChanged() { paper.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    const w = width, h = height
                    // gun-iron paper: pal.glass pulled down toward the night
                    ctx.fillStyle = String(Qt.rgba(chrome.pal.glass.r * 0.6,
                                                   chrome.pal.glass.g * 0.6,
                                                   chrome.pal.glass.b * 0.6, 0.95))
                    ctx.fillRect(0, 0, w, h)
                    // double ledger rule frame
                    ctx.strokeStyle = String(chrome.boneA(0.55))
                    ctx.lineWidth = 1.6
                    ctx.strokeRect(2, 2, w - 4, h - 4)
                    ctx.strokeStyle = String(chrome.boneA(0.18))
                    ctx.lineWidth = 1
                    ctx.strokeRect(7.5, 7.5, w - 15, h - 15)
                    // corner rivets
                    ctx.fillStyle = String(chrome.boneA(0.6))
                    for (const [rx, ry] of [[5, 5], [w - 5, 5], [5, h - 5], [w - 5, h - 5]]) {
                        ctx.beginPath()
                        ctx.arc(rx, ry, 2, 0, 6.2832)
                        ctx.fill()
                    }
                }
            }
        }
    }

    // ── header: fog EQ + uptime ─────────────────────────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 14

            Item {
                width: parent.width
                height: 16

                // three lanterns in the fog — bass/mid/high off the shell's cava
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Repeater {
                        model: ["bass", "mid", "high"]
                        delegate: Rectangle {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: chrome.boneA(0.25 + 0.7 * Math.min(1, chrome.audio[modelData] || 0))
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: chrome.popup.uptimeText
                    font.family: chrome.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: chrome.pal.dim
                }
            }

            // double rule under the header
            Column {
                width: parent.width
                spacing: 2
                Rectangle { width: parent.width; height: 1; color: chrome.boneA(0.35) }
                Rectangle { width: parent.width; height: 1; color: chrome.boneA(0.12) }
            }
        }
    }

    // ── footer: the connection's state ──────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 14

            Rectangle { width: parent.width; height: 1; color: chrome.boneA(0.25) }

            Item {
                width: parent.width
                height: 13

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5; radius: 2.5
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.boneA(0.8)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                }
            }
        }
    }

    // ── overlay: faint ledger ruling — paper grain, no input handlers ──────
    readonly property Component overlay: Component {
        Item {
            id: ov
            Canvas {
                anchors.fill: parent
                opacity: 0.5
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = String(chrome.boneA(0.05))
                    ctx.lineWidth = 1
                    for (let y = 30; y < height - 12; y += 27) {
                        ctx.beginPath(); ctx.moveTo(12, y); ctx.lineTo(width - 12, y); ctx.stroke()
                    }
                }
            }
            // fog pooling at the card's foot
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.min(50, parent.height * 0.2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(chrome.pal.cyan.r, chrome.pal.cyan.g, chrome.pal.cyan.b, 0.05) }
                }
            }
        }
    }
}
