import QtQuick

// stillwater: chrome for the Super+M control menu. The shell mounts these
// pieces around its shared tabs: backdrop (deep-water glass with a dusk-rose
// glow pooling at the top and the card's own waterline near its foot — five
// small lamps standing on it, each doubled as a broken streak), header (a
// breathing lamp + the theme's name + a three-lamp equalizer whose streaks
// stretch with the music + the evening's age), footer (the far shore's
// answer + the send-off), overlay (faint sliver lines across the water zone).
// Item root that renders nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function lampA(a)  { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function skyA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    // the backdrop draws the face; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 12

    // ── backdrop: the water card ────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd
            readonly property real wl: height * 0.74

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: chrome.glassA(0.94)
                border.width: 1
                border.color: chrome.skyA(0.30)
            }
            // dusk pooling down from the top — the sky half of the card
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(120, parent.height * 0.4)
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(chrome.pal.magenta.r, chrome.pal.magenta.g, chrome.pal.magenta.b, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            // below the waterline the glass turns a shade more luminous
            Rectangle {
                x: 1; y: bd.wl
                width: parent.width - 2
                height: parent.height - bd.wl - 1
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.skyA(0.06) }
                    GradientStop { position: 1.0; color: chrome.skyA(0.02) }
                }
            }
            // the card's waterline
            Rectangle {
                x: 10; y: bd.wl
                width: parent.width - 20
                height: 1
                color: chrome.skyA(0.25)
            }
            // five lamps standing on it, doubled beneath
            Repeater {
                model: 5
                Item {
                    id: shoreLamp
                    required property int index
                    readonly property real fx: 0.14 + index * 0.18
                    readonly property real lv: index === 2 ? 0.9 : 0.35 + ((index * 37) % 40) / 100
                    x: Math.round(bd.width * fx)
                    y: bd.wl
                    Rectangle {
                        x: -2; y: -3
                        width: 4; height: 4
                        radius: 2
                        color: chrome.lampA(0.25 + 0.6 * shoreLamp.lv)
                    }
                    Column {
                        x: -1.5; y: 3
                        spacing: 2
                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                width: 3 - index; height: 2
                                color: chrome.lampA(shoreLamp.lv * (0.3 - index * 0.12))
                            }
                        }
                    }
                }
            }
        }
    }

    // ── header: lamp + name + the three lamps of the music + the evening ────
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

                    Rectangle {
                        id: pip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6
                        radius: 3
                        color: chrome.pal.neon
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 2000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "STILLWATER"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 5
                        color: chrome.pal.neon
                    }

                    // three lamps on a tiny waterline; their streaks stretch
                    // with the music, the way light lies longer on stirred water
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 20
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Rectangle { x: 0; y: 7; width: 40; height: 1; color: chrome.skyA(0.3) }
                        Repeater {
                            model: [
                                { band: "bass", fx: 6 },
                                { band: "mid",  fx: 19 },
                                { band: "high", fx: 32 }
                            ]
                            delegate: Item {
                                required property var modelData
                                readonly property real lv: Math.min(1, chrome.audio[modelData.band] || 0)
                                x: modelData.fx
                                y: 7
                                Rectangle {
                                    x: -2; y: -3; width: 4; height: 4; radius: 2
                                    color: chrome.lampA(0.3 + 0.7 * parent.lv)
                                }
                                Rectangle {
                                    x: -1; y: 2
                                    width: 2
                                    height: 2 + 9 * parent.lv
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: chrome.lampA(0.5) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }
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
                        text: "the evening, " + chrome.popup.uptimeText.replace("up ", "") + " in"
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.slateA(1.0)
                    }
                }
            }

            // the waterline across the dialog
            Rectangle {
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.15; color: chrome.skyA(0.35) }
                    GradientStop { position: 0.85; color: chrome.skyA(0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ── footer: the far shore + the send-off ────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.15; color: chrome.slateA(0.5) }
                    GradientStop { position: 0.85; color: chrome.slateA(0.5) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Item {
                width: parent.width
                height: 14

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5; height: 5
                        radius: 2.5
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.neon
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "the far shore is dark"
                            : (chrome.popup.connName || "the far shore answers")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.inkA(0.7)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "the water holds the light"
                    font.family: chrome.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    color: chrome.lampA(0.55)
                }
            }
        }
    }

    // ── overlay: faint sliver lines across the card's water zone ────────────
    readonly property Component overlay: Component {
        Canvas {
            id: slivers
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (width <= 0 || height <= 0) return
                const wl = height * 0.74
                ctx.fillStyle = "rgba(255,255,255,0.022)"
                let y = wl + 4, k = 0
                while (y < height - 4) {
                    const inset = 12 + (k % 3) * 16
                    ctx.fillRect(inset, y, width - inset * 2, 1)
                    y += 6 + k * 2
                    k++
                }
            }
        }
    }
}
