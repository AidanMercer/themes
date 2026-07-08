import QtQuick

// fuel: service-station chrome for the Super+M control popup.
//
// The shell's ControlPopup loads this next to the wallpaper and mounts the
// pieces around its shared tabs: backdrop (a chamfered pump placard whose top
// edge carries the bent canopy neon stripe, pump band in the top-right cut),
// header (pilot lamp + FUEL // STATION CTRL + live flow pips + uptime),
// footer (LINE status + pump-band divider + sign-off), overlay (a slow,
// rare sweep of the 3-stripe band down the glass). Item root because the
// Loader refuses non-visual elements; it renders nothing itself.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    // the chassis canvas draws its own fill + edges, so the card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 0

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"

    // ── backdrop: chamfered pump placard, canopy stripe bent over the top ──
    readonly property Component backdrop: Component {
        Item {
            Canvas {
                id: chassis
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                // pal reads config.toml async — retint if it lands after first paint
                Connections {
                    target: chrome.pal
                    function onNeonChanged()    { chassis.requestPaint() }
                    function onAmberChanged()   { chassis.requestPaint() }
                    function onMagentaChanged() { chassis.requestPaint() }
                    function onDimChanged()     { chassis.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height, c = 14
                    ctx.reset()
                    // pump placard: all four corners chamfered
                    ctx.beginPath()
                    ctx.moveTo(c, 0); ctx.lineTo(w - c, 0); ctx.lineTo(w, c)
                    ctx.lineTo(w, h - c); ctx.lineTo(w - c, h); ctx.lineTo(c, h)
                    ctx.lineTo(0, h - c); ctx.lineTo(0, c)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(5,8,12,0.96)"
                    ctx.fill()
                    ctx.strokeStyle = chrome.pal.dim
                    ctx.globalAlpha = 0.6
                    ctx.lineWidth = 1
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    // canopy neon: along the top edge, bending down both chamfers
                    ctx.beginPath()
                    ctx.moveTo(1, c + 5); ctx.lineTo(c + 2, 1.2)
                    ctx.lineTo(w - c - 2, 1.2); ctx.lineTo(w - 1, c + 5)
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineWidth = 5
                    ctx.globalAlpha = 0.18
                    ctx.stroke()
                    ctx.lineWidth = 1.5
                    ctx.globalAlpha = 0.95
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    // pump band riding the top-right chamfer: three 45° stripes
                    const bands = [chrome.pal.amber, chrome.pal.neon, chrome.pal.magenta]
                    for (let i = 0; i < 3; i++) {
                        ctx.beginPath()
                        ctx.moveTo(w - c - 12 - i * 7, 4)
                        ctx.lineTo(w - 4 - i * 7, c + 12)
                        ctx.strokeStyle = bands[i]
                        ctx.globalAlpha = 0.5
                        ctx.lineWidth = 3
                        ctx.stroke()
                    }
                    ctx.globalAlpha = 1
                    // amber corner tick, bottom-left
                    ctx.beginPath()
                    ctx.moveTo(4, h - 22); ctx.lineTo(4, h - c + 2); ctx.lineTo(18, h - 5)
                    ctx.strokeStyle = chrome.pal.amber
                    ctx.globalAlpha = 0.8
                    ctx.lineWidth = 1.5
                    ctx.stroke()
                    ctx.globalAlpha = 1
                }
            }
        }
    }

    // ── header: pilot lamp + FUEL + flow pips, // STATION CTRL + uptime ──
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 18

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // pilot lamp, breathing while the popup is open
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: chrome.pal.amber
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                    // mini pump band
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Rectangle { width: 14; height: 2; color: chrome.pal.amber }
                        Rectangle { width: 14; height: 2; color: chrome.pal.neon }
                        Rectangle { width: 14; height: 2; color: chrome.pal.magenta }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "FUEL"
                        font.family: chrome.mono
                        font.weight: Font.Black
                        font.pixelSize: 13
                        font.letterSpacing: 5
                        color: chrome.pal.text
                    }

                    // live flow pips — bass/mid/high off the shell's cava
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 12
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { px: 0,  band: "bass", col: chrome.pal.amber },
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
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "// STATION CTRL"
                        font.family: chrome.mono
                        font.pixelSize: 9
                        font.letterSpacing: 2
                        color: chrome.pal.cyan
                        opacity: 0.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "UP " + chrome.popup.uptimeText.replace("up ", "").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: chrome.pal.dim
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.pal.dim
                opacity: 0.5
            }
        }
    }

    // ── footer: LINE status + pump band + sign-off ──
    readonly property Component footer: Component {
        Column {
            spacing: 12

            // the divider is the pump band itself, quiet
            Column {
                width: parent.width
                spacing: 2
                Rectangle { width: parent.width; height: 1; color: chrome.pal.amber; opacity: 0.4 }
                Rectangle { width: parent.width; height: 1; color: chrome.pal.neon; opacity: 0.5 }
                Rectangle { width: parent.width; height: 1; color: chrome.pal.magenta; opacity: 0.35 }
            }

            Item {
                width: parent.width
                height: 13

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
                        text: chrome.popup.connType === "none" ? "LINE DOWN"
                            : "LINE · " + (chrome.popup.connName || "ONLINE")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "// MIDNIGHT FUEL STOP"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: chrome.pal.neon
                        opacity: 0.55
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 11
                        color: chrome.pal.amber
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 0 }
                            PauseAnimation { duration: 440 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 440 }
                        }
                    }
                }
            }
        }
    }

    // ── overlay: a rare, quiet sweep of the pump band down the glass ──
    // No MouseArea anywhere, so clicks pass straight through to the tabs.
    readonly property Component overlay: Component {
        Item {
            id: ov

            Column {
                id: sweep
                width: ov.width
                spacing: 3
                opacity: 0
                y: 0
                Rectangle { width: parent.width; height: 1.5; color: chrome.pal.amber }
                Rectangle { width: parent.width; height: 1.5; color: chrome.pal.neon }
                Rectangle { width: parent.width; height: 1.5; color: chrome.pal.magenta }

                SequentialAnimation {
                    running: chrome.popup.open
                    loops: Animation.Infinite
                    PauseAnimation { duration: 7000 }
                    ScriptAction { script: { sweep.y = 0; sweep.opacity = 0.10 } }
                    NumberAnimation { target: sweep; property: "y"; to: ov.height; duration: 1600; easing.type: Easing.InOutSine }
                    ScriptAction { script: sweep.opacity = 0 }
                }
            }
        }
    }
}
