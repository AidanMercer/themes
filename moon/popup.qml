import QtQuick

// Cyberpunk: Edgerunners chrome for the Super+M control popup.
//
// The shell's ControlPopup loads this next to the wallpaper and mounts the
// pieces around its shared tabs: backdrop behind the content (chamfered chassis,
// corner brackets), header (blink pip + SYSTEM + live EQ // CTRL.DECK + uptime),
// footer (NET status + EDGERUNNER sign-off), overlay on top (CRT scanlines,
// optional scan beam). Self-contained like the other moon widgets. Item root
// (not QtObject) because Loader refuses non-visual elements; it renders nothing
// itself — the shell mounts the Components below into its own slots.
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

    // roaming scan beam — off by default (a transient popup shouldn't sweep
    // while you're aiming at a slider); flip to true to opt in.
    property bool scanBeam: false

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    readonly property string iconArch: String.fromCodePoint(0xF303) // nf-linux-archlinux

    // ── chassis: chamfered frame drawn behind the content. Top-left +
    // bottom-right corner cuts, a faint wide glow stroke under a crisp neon
    // edge, a cyan inner rule along the top and a magenta corner tick bottom-
    // right — sysinfo.qml's HUD grammar. The card grows per tab, so repaint on
    // size. Cyan L-brackets lock the two square corners. ──
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Canvas {
                id: chassis
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                // pal reads config.toml async — retint if it lands after first paint
                Connections {
                    target: chrome.pal
                    function onNeonChanged() { chassis.requestPaint() }
                    function onCyanChanged() { chassis.requestPaint() }
                    function onMagentaChanged() { chassis.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    const w = width, h = height, c = 13
                    ctx.reset()
                    ctx.beginPath()
                    ctx.moveTo(c, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h - c)
                    ctx.lineTo(w - c, h); ctx.lineTo(0, h); ctx.lineTo(0, c)
                    ctx.closePath()
                    ctx.fillStyle = "rgba(7,7,12,0.95)"
                    ctx.fill()
                    // fake glow: wide low-alpha stroke first, crisp edge on top
                    ctx.strokeStyle = chrome.pal.neon
                    ctx.lineWidth = 3
                    ctx.globalAlpha = 0.18
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    ctx.lineWidth = 1.4
                    ctx.stroke()
                    // cyan inner rule under the top edge
                    ctx.beginPath()
                    ctx.moveTo(14, 4); ctx.lineTo(w - 6, 4)
                    ctx.strokeStyle = chrome.pal.cyan
                    ctx.lineWidth = 1
                    ctx.globalAlpha = 0.5
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    // magenta corner tick, bottom-right
                    ctx.beginPath()
                    ctx.moveTo(w - 4, h - 22); ctx.lineTo(w - 4, h - 6); ctx.lineTo(w - 20, h - 6)
                    ctx.strokeStyle = chrome.pal.magenta
                    ctx.lineWidth = 1.6
                    ctx.stroke()
                }
            }

            Repeater {
                model: [
                    { ax: "right", ay: "top" },
                    { ax: "left",  ay: "bottom" }
                ]
                delegate: Item {
                    required property var modelData
                    width: 16
                    height: 16
                    x: modelData.ax === "left" ? 0 : bd.width - width
                    y: modelData.ay === "top" ? 0 : bd.height - height

                    Rectangle {
                        width: parent.width
                        height: 2
                        color: chrome.pal.cyan
                        y: parent.modelData.ay === "top" ? 0 : parent.height - height
                    }
                    Rectangle {
                        width: 2
                        height: parent.height
                        color: chrome.pal.cyan
                        x: parent.modelData.ax === "left" ? 0 : parent.width - width
                    }
                }
            }
        }
    }

    // ── header: blink pip + SYSTEM + live EQ, // CTRL.DECK + UP uptime ──
    readonly property Component header: Component {
        Column {
            spacing: 14

            Item {
                width: parent.width
                height: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 1
                        color: chrome.pal.magenta
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700 }
                            NumberAnimation { to: 1.0; duration: 700 }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.iconArch
                        font.family: chrome.icon
                        font.pixelSize: 13
                        color: chrome.pal.cyan
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SYSTEM"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        color: chrome.pal.neon
                    }

                    // live audio EQ — bass/mid/high straight off the shell's cava.
                    // dances while anything's playing, drops flat + dim when quiet.
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
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "// CTRL.DECK"
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

    // ── footer: NET status (left) + EDGERUNNER sign-off (right) ──
    readonly property Component footer: Component {
        Column {
            spacing: 14

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.pal.dim
                opacity: 0.5
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
                        text: chrome.popup.connType === "none" ? "OFFLINE"
                            : (chrome.popup.connName || "ONLINE")
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                }

                Row {
                    anchors.right: parent.right
                    // clear the bottom-right chamfer + magenta corner tick (~20px in)
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "// EDGERUNNER CTRL"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: chrome.pal.neon
                        opacity: 0.55
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 11
                        color: chrome.pal.neon
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

    // ── overlay: faint CRT scanlines over the whole card + optional beam.
    // No MouseArea anywhere, so clicks pass straight through to the tabs. ──
    readonly property Component overlay: Component {
        Item {
            id: ov

            Canvas {
                anchors.fill: parent
                opacity: 0.4
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "rgba(0,0,0,0.5)"
                    ctx.lineWidth = 1
                    for (let y = 3; y < height; y += 3) {
                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                    }
                }
            }

            Rectangle {
                visible: chrome.scanBeam
                width: ov.width
                height: 2
                color: chrome.pal.cyan
                opacity: 0.25
                SequentialAnimation on y {
                    running: chrome.popup.open && chrome.scanBeam
                    loops: Animation.Infinite
                    NumberAnimation { to: ov.height; duration: 4200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 1600 }
                }
            }
        }
    }
}
