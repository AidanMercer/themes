import QtQuick

// pines: chrome for the Super+M control menu. The shell keeps its shared
// tabs; this file dresses them as the lookout's map table: a slate card with
// faint topographic contour lines inked across it, a hairline frame with
// lamp-warm corner ticks, the kerosene pip and a live draught gauge riding
// the audio bus in the head, uptime and net status in plain words.
// Invisible Item root — the shell mounts the pieces.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string serif: "Noto Serif Display"
    function lampA(a)   { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function silverA(a) { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }

    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.93)
    readonly property color cardBorder: silverA(0.35)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 5

    // ── backdrop: the map table — contour lines + corner ticks ─────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // topographic contours around two quiet summits, inked once
            Canvas {
                id: topo
                anchors.fill: parent
                opacity: 0.5
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
                Connections {
                    target: chrome.pal
                    function onDimChanged() { topo.requestPaint() }
                    function onCyanChanged() { topo.requestPaint() }
                }
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    if (width <= 0 || height <= 0) return
                    ctx.lineWidth = 1
                    const peaks = [
                        { cx: width * 0.80, cy: height * 0.18, r0: 26, ph: 1.7 },
                        { cx: width * 0.12, cy: height * 0.88, r0: 20, ph: 4.1 }
                    ]
                    for (const pk of peaks) {
                        for (let ring = 0; ring < 5; ring++) {
                            const base = pk.r0 + ring * 24
                            ctx.beginPath()
                            for (let a = 0; a <= 64; a++) {
                                const th = a / 64 * Math.PI * 2
                                const r = base
                                    + Math.sin(th * 3 + pk.ph + ring * 0.8) * base * 0.14
                                    + Math.sin(th * 5 + pk.ph * 2.3) * base * 0.07
                                const x = pk.cx + Math.cos(th) * r
                                const y = pk.cy + Math.sin(th) * r * 0.82
                                if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                            }
                            ctx.closePath()
                            ctx.strokeStyle = chrome.pal.dim
                            ctx.globalAlpha = 0.16 - ring * 0.022
                            ctx.stroke()
                        }
                        // the summit's benchmark
                        ctx.globalAlpha = 0.30
                        ctx.strokeStyle = chrome.pal.cyan
                        ctx.beginPath()
                        ctx.moveTo(pk.cx, pk.cy - 4)
                        ctx.lineTo(pk.cx + 4, pk.cy + 3)
                        ctx.lineTo(pk.cx - 4, pk.cy + 3)
                        ctx.closePath()
                        ctx.stroke()
                    }
                }
            }

            // lamplight falling across the head of the table
            Rectangle {
                width: parent.width; height: 46
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.lampA(0.07) }
                    GradientStop { position: 1.0; color: chrome.lampA(0.0) }
                }
            }

            // lamp-warm corner ticks
            Repeater {
                model: [
                    { lx: true,  ty: true  }, { lx: false, ty: false }
                ]
                delegate: Item {
                    required property var modelData
                    width: 12; height: 12
                    x: modelData.lx ? 0 : bd.width - width
                    y: modelData.ty ? 0 : bd.height - height
                    Rectangle {
                        width: parent.width; height: 1.4
                        color: chrome.lampA(0.6)
                        y: parent.modelData.ty ? 0 : parent.height - height
                    }
                    Rectangle {
                        width: 1.4; height: parent.height
                        color: chrome.lampA(0.6)
                        x: parent.modelData.lx ? 0 : parent.width - width
                    }
                }
            }
        }
    }

    // ── header: lamp pip + draught gauge // uptime ─────────────────────────
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

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: chrome.pal.neon
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                        }
                    }
                    // the draught gauge: three hairline needles riding the mix
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 12
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 0.9 : 0.25
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { px: 0,  band: "bass" },
                                { px: 5,  band: "mid" },
                                { px: 10, band: "high" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.px
                                width: 1.6
                                anchors.bottom: parent.bottom
                                color: chrome.silverA(0.9)
                                height: 2 + 10 * Math.min(1, chrome.audio[modelData.band] || 0)
                                Behavior on height { NumberAnimation { duration: 90 } }
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
                    font.letterSpacing: 1
                    color: chrome.silverA(0.7)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.pal.dim
                opacity: 0.55
            }
        }
    }

    // ── footer: net status ─────────────────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.pal.dim
                opacity: 0.55
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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.silverA(0.95)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.silverA(0.85)
                    }
                }
            }
        }
    }
}
