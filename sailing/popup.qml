import QtQuick

// sailing: cabin chrome for the Super+M control popup — a varnished cabin
// panel below decks. Deep navy glass with a brass hairline, porthole-radius
// corners marked by quarter-circle brass arcs, a ship's nameplate for a
// header over a railing rule, and a small lifebuoy ring resting in the
// bottom-right corner. The footer keeps the radio log: shore link left,
// the deck sign-off right. A whisper of rain slants across the varnish.
// Renders nothing itself — the shell mounts the Components into its slots.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property color buoy:  pal.neon
    readonly property color dusk:  pal.cyan
    readonly property color alarm: pal.magenta
    readonly property color lamp:  pal.amber
    readonly property color slate: pal.dim
    readonly property color pale:  pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function paleA(a)  { return Qt.rgba(pale.r, pale.g, pale.b, a) }
    function duskA(a)  { return Qt.rgba(dusk.r, dusk.g, dusk.b, a) }
    function lampA(a)  { return Qt.rgba(lamp.r, lamp.g, lamp.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function buoyA(a)  { return Qt.rgba(buoy.r, buoy.g, buoy.b, a) }

    // the card: deep navy varnish, brass hairline, porthole-round corners
    readonly property color cardBg: Qt.rgba(glass.r, glass.g, glass.b, 0.94)
    readonly property color cardBorder: lampA(0.38)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 14

    // ── backdrop: corner arcs + the lifebuoy in the corner ──────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // varnish sheen: slightly deeper toward the base
            Rectangle {
                anchors.fill: parent
                radius: chrome.cardRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.025) }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.18) }
                }
            }

            // brass quarter-arcs hugging the porthole corners
            Canvas {
                id: corners
                anchors.fill: parent
                Connections {
                    target: chrome.pal
                    function onAmberChanged() { corners.requestPaint() }
                    function onNeonChanged() { corners.requestPaint() }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height, r = 22
                    ctx.strokeStyle = chrome.lampA(0.7)
                    ctx.lineWidth = 1.4
                    ctx.beginPath(); ctx.arc(r + 5, r + 5, r, Math.PI, Math.PI * 1.5); ctx.stroke()
                    ctx.beginPath(); ctx.arc(w - r - 5, r + 5, r, Math.PI * 1.5, Math.PI * 2); ctx.stroke()
                    ctx.beginPath(); ctx.arc(r + 5, h - r - 5, r, Math.PI * 0.5, Math.PI); ctx.stroke()
                    ctx.beginPath(); ctx.arc(w - r - 5, h - r - 5, r, 0, Math.PI * 0.5); ctx.stroke()

                    // the lifebuoy: a small ring with four red-orange segments,
                    // hung inside the bottom-right corner
                    const bx = w - 30, by = h - 30, br = 9
                    ctx.lineWidth = 4
                    ctx.strokeStyle = chrome.paleA(0.5)
                    ctx.beginPath(); ctx.arc(bx, by, br, 0, Math.PI * 2); ctx.stroke()
                    ctx.strokeStyle = chrome.buoyA(0.9)
                    for (let i = 0; i < 4; i++) {
                        const a0 = i * Math.PI / 2 + Math.PI / 8
                        ctx.beginPath(); ctx.arc(bx, by, br, a0, a0 + Math.PI / 4); ctx.stroke()
                    }
                }
            }
        }
    }

    // ── header: the ship's nameplate over a railing rule ────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 20

                // deck lamp, breathing only while the panel is open
                Rectangle {
                    id: lampDot
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: chrome.lamp
                    SequentialAnimation on opacity {
                        running: chrome.popup.open
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }

                // nameplate, centered between hairlines
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 1; color: chrome.lampA(0.5)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "M.V. THROUGH SILENCE"
                        color: chrome.pale
                        font.family: chrome.serif
                        font.pixelSize: 13
                        font.letterSpacing: 6
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 1; color: chrome.lampA(0.5)
                    }
                }

                // the swell meter: three soft bars riding the audio bus
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    opacity: (chrome.audio.ready && !chrome.audio.silent) ? 0.9 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                    Repeater {
                        model: ["bass", "mid", "high"]
                        delegate: Item {
                            required property string modelData
                            width: 3; height: 12
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: 3
                                radius: 1.5
                                color: chrome.duskA(0.9)
                                height: 3 + 9 * Math.min(1, chrome.audio[parent.modelData] || 0)
                                Behavior on height { NumberAnimation { duration: 90 } }
                            }
                        }
                    }
                }
            }

            // railing rule: two hairlines + stanchion posts
            Item {
                width: parent.width
                height: 8
                Rectangle { y: 1; width: parent.width; height: 1; color: chrome.paleA(0.26) }
                Rectangle { y: 5; width: parent.width; height: 1; color: chrome.slateA(0.55) }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        x: index === 4 ? parent.width - 2 : Math.round(parent.width * index / 4)
                        width: 2; height: 7
                        color: chrome.paleA(0.45)
                    }
                }
            }
        }
    }

    // ── footer: the radio log ───────────────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 8
                Rectangle { y: 1; width: parent.width; height: 1; color: chrome.paleA(0.26) }
                Rectangle { y: 5; width: parent.width; height: 1; color: chrome.slateA(0.55) }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        x: index === 4 ? parent.width - 2 : Math.round(parent.width * index / 4)
                        width: 2; height: 7
                        color: chrome.paleA(0.45)
                    }
                }
            }

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
                        color: chrome.popup.connType === "none" ? chrome.alarm : chrome.duskA(0.9)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "RADIO — NO SIGNAL"
                            : "RADIO — " + (chrome.popup.connName || "SHORE LINK").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        color: chrome.popup.connType === "none" ? chrome.alarm : chrome.duskA(0.8)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AT SEA " + chrome.popup.uptimeText.replace("up ", "").toUpperCase() + "  ·  DECK B"
                    font.family: chrome.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: chrome.slateA(1)
                }
            }
        }
    }

    // ── overlay: a whisper of rain across the varnish, click-through ────────
    readonly property Component overlay: Component {
        Canvas {
            opacity: 0.5
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Qt.rgba(chrome.pale.r, chrome.pale.g, chrome.pale.b, 0.05)
                ctx.lineWidth = 1
                // sparse slanted rain, deterministic
                for (let i = 0; i < 14; i++) {
                    const x = ((i * 0.6180339) % 1) * width
                    const y = ((i * 0.3819661) % 1) * height
                    const len = 14 + (i % 5) * 6
                    ctx.beginPath()
                    ctx.moveTo(x, y)
                    ctx.lineTo(x - len * 0.18, y + len)
                    ctx.stroke()
                }
            }
        }
    }
}
