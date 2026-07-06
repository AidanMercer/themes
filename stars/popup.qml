import QtQuick

// stars: vending-machine chrome for the Super+M control popup. The shell
// mounts these pieces around its shared tabs: backdrop (the machine's front
// — night glass, warm inner glow along the lit top, faint product-window
// mullions, a coin slot bottom-right), header (the lit vendor sign with a
// pulsing star pip + a tiny bottle EQ riding the music + uptime), footer
// (NET + "thank you ✦ come again"), overlay (a static glass sheen). Item
// root that renders nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function inkA(a)   { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function amberA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function slateA(a) { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    // the backdrop draws the machine face; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 12

    // ── backdrop: the machine's front ───────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // chassis
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: chrome.glassA(0.95)
                border.width: 1
                border.color: chrome.amberA(0.5)
            }
            // soft outer halo — the machine glowing into the night
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 16
                color: "transparent"
                border.width: 4
                border.color: chrome.amberA(0.08)
            }
            // warm light down from the lit header area
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: Math.min(120, parent.height * 0.4)
                radius: 11
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.amberA(0.12) }
                    GradientStop { position: 1.0; color: chrome.amberA(0.0) }
                }
            }
            // faint product-window mullions
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    x: bd.width * (0.25 + index * 0.25)
                    y: 10
                    width: 1
                    height: bd.height - 20
                    color: chrome.inkA(0.045)
                }
            }
            // coin slot + return flap, bottom-right of the face
            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: 12
                spacing: 5
                Rectangle {
                    anchors.right: parent.right
                    width: 4; height: 16; radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: chrome.slateA(0.9)
                }
                Text {
                    anchors.right: parent.right
                    text: "✧"
                    font.pixelSize: 9
                    color: chrome.slateA(0.9)
                }
            }
        }
    }

    // ── header: the lit vendor sign ─────────────────────────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✦"
                        font.pixelSize: 12
                        color: chrome.pal.neon
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1300; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1300; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SEASIDE VENDOR"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 4
                        color: chrome.pal.neon
                    }

                    // tiny bottle EQ — three bottles filling with bass/mid/high
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.neon },
                                { band: "mid",  col: chrome.pal.cyan },
                                { band: "high", col: chrome.pal.text }
                            ]
                            delegate: Item {
                                required property var modelData
                                width: 6; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {   // bottle outline
                                    anchors.fill: parent
                                    radius: 2.5
                                    color: "transparent"
                                    border.width: 1
                                    border.color: chrome.slateA(0.9)
                                }
                                Rectangle {   // the fill level
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 2
                                    radius: 2
                                    height: 2 + (parent.height - 4) * Math.min(1, chrome.audio[modelData.band] || 0)
                                    color: modelData.col
                                    opacity: 0.9
                                    Behavior on height { NumberAnimation { duration: 80 } }
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
                        text: "COLD DRINKS · 24H"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: chrome.pal.cyan
                        opacity: 0.75
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "UP " + chrome.popup.uptimeText.replace("up ", "").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.slateA(1.0)
                    }
                }
            }

            // shelf rule with a dotted product row
            Item {
                width: parent.width
                height: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: chrome.slateA(0.6)
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 26
                    Repeater {
                        model: 7
                        Rectangle {
                            width: 3; height: 5; radius: 1
                            color: chrome.amberA(0.55)
                        }
                    }
                }
            }
        }
    }

    // ── footer: net + the vendor's goodbye ──────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Rectangle {
                width: parent.width
                height: 1
                color: chrome.slateA(0.6)
            }

            Item {
                width: parent.width
                height: 14

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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.inkA(0.75)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THANK YOU ✦ COME AGAIN"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: chrome.amberA(0.6)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✧"
                        font.pixelSize: 10
                        color: chrome.pal.cyan
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 1700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.9; duration: 1700; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }

    // ── overlay: a still sheen down the machine's glass ────────────────────
    readonly property Component overlay: Component {
        Item {
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                width: parent.width * 0.45
                height: parent.height
                opacity: 0.05
                rotation: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.pal.text }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }
}
