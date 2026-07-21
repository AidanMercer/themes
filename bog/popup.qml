import QtQuick

// bog: chrome for the Super+M control menu — a big lily pad of dark water.
// The shell mounts these pieces around its shared tabs: backdrop (organic
// murk-glass card, a waterline across the top with sun-glints, ripple rings
// drifting across the face while it's open, the little leaf-sail raft
// resting in the bottom corner), header (a cork pip dipping on the line +
// three reed-stem levels swaying with the music + uptime),
// footer (the connection and its name).
// Item root that renders nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string serif: "Noto Serif Display"
    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function strawA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function sunA(a)   { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function mossA(a)  { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function reedA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function murkA(a)  { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    // the backdrop draws the pad; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 18

    // ── backdrop: the pad ───────────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: chrome.murkA(0.95)
                border.width: 1
                border.color: chrome.mossA(0.4)
            }
            // noon light pooling down from the waterline
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: Math.min(90, parent.height * 0.3)
                radius: 17
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.sunA(0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // the waterline across the top of the pad
            Rectangle {
                x: 16; y: 34
                width: parent.width - 32
                height: 1
                color: chrome.reedA(0.55)
            }
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    x: 24 + index * ((bd.width - 60) / 5)
                    y: 33
                    width: index % 2 === 0 ? 18 : 9
                    height: 2
                    radius: 1
                    color: chrome.sunA(0.28)
                }
            }

            // ripple rings drifting across the face, one after another,
            // only while the pad is up
            Repeater {
                model: 2
                Canvas {
                    id: drift
                    required property int index
                    property real t: 0
                    x: bd.width * (index === 0 ? 0.18 : 0.68)
                    y: bd.height * (index === 0 ? 0.55 : 0.75)
                    width: 90; height: 34
                    opacity: 0.6
                    onTChanged: requestPaint()
                    NumberAnimation on t {
                        from: 0; to: 1
                        duration: 5200 + drift.index * 1700
                        loops: Animation.Infinite
                        running: chrome.popup.open
                    }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const tt = t
                        const r = (width / 2) * (0.1 + 0.9 * tt)
                        ctx.save()
                        ctx.translate(width / 2, height / 2)
                        ctx.scale(1, 0.3)
                        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
                        ctx.restore()
                        ctx.strokeStyle = String(chrome.sunA(0.18 * (1 - tt)))
                        ctx.lineWidth = 1.2
                        ctx.stroke()
                    }
                }
            }

            // the raft, resting in the bottom-right of the pad
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 20
                anchors.bottomMargin: 14
                width: 30; height: 20
                opacity: 0.55
                // hull leaf
                Rectangle { x: 2; y: 14; width: 24; height: 4; radius: 2; color: chrome.mossA(0.9) }
                // mast
                Rectangle { x: 12; y: 2; width: 1.4; height: 12; color: chrome.reedA(1) }
                // leaf-sail
                Rectangle { x: 13.5; y: 2; width: 9; height: 8; radius: 4; color: chrome.mossA(0.7) }
                // the two little fishers
                Rectangle { x: 6; y: 10; width: 4; height: 4; radius: 2; color: chrome.mossA(1) }
                Rectangle { x: 19; y: 11; width: 4; height: 3; radius: 1.5; color: Qt.rgba(chrome.pal.amber.r, chrome.pal.amber.g, chrome.pal.amber.b, 0.9) }
            }
        }
    }

    // ── header: cork pip + reed levels + uptime ─────────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // the cork pip, dipping slowly while the pad is up
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 10
                        property real dip: 0
                        Rectangle { x: 0; y: 0 + parent.dip; width: 7; height: 4.4; radius: 2.2; color: chrome.pal.magenta }
                        Rectangle { x: 1; y: 3.8 + parent.dip; width: 5; height: 3.6; radius: 1.8; color: chrome.sunA(0.85) }
                        SequentialAnimation on dip {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.8; duration: 1700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -0.6; duration: 1700; easing.type: Easing.InOutSine }
                        }
                    }
                    // three reed stems, swaying taller with the music
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.cyan },
                                { band: "mid",  col: chrome.pal.neon },
                                { band: "high", col: chrome.pal.text }
                            ]
                            delegate: Item {
                                required property var modelData
                                readonly property real v: Math.min(1, chrome.audio[modelData.band] || 0)
                                width: 4; height: 16
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 2
                                    height: 3 + parent.v * 13
                                    radius: 1
                                    color: modelData.col
                                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutSine } }
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
                    color: chrome.reedA(1.0)
                }
            }
        }
    }

    // ── footer: the connection and its name ─────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 10

            Rectangle { width: parent.width; height: 1; color: chrome.reedA(0.4) }

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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "connected")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.strawA(0.7)
                    }
                }
            }
        }
    }
}
