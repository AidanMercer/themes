import QtQuick

// sleeper: night-service tray chrome for the Super+M control popup. The shell
// mounts these pieces around its shared tabs: backdrop (the attendant's tray —
// compartment glass with a warm rim, a doily of punch-dots along the top, a
// tiny podstakannik parked in the bottom corner), header (the reading lamp +
// THE OVERNIGHT BERTH + three little tea glasses as the EQ + distance),
// footer (the line + SLEEP WELL), overlay (every little while a lamp passes
// across the tray — light arrives as passing glows here). Item root that
// renders nothing itself; no MouseAreas, clicks pass through.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // neon/cyan/magenta/amber/dim/text/glass
    required property var popup    // open, uptimeText, connType, connName
    required property var audio    // AudioBus: bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string icon: "Symbols Nerd Font"
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }
    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function woodA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function glassA(a) { return Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, a) }

    // the backdrop draws the tray; the shell's card stays bare
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 6

    // ── backdrop: the tray ──────────────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {   // tray face
                anchors.fill: parent
                radius: 6
                color: chrome.glassA(0.95)
                border.width: 1
                border.color: chrome.teaA(0.45)
            }
            Rectangle {   // inner wood rule
                anchors.fill: parent
                anchors.margins: 4
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: chrome.woodA(0.6)
            }
            // warm lamplight pooling from the top
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: Math.min(110, parent.height * 0.35)
                radius: 5
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.09) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            // the doily: a row of punch-dots along the top edge
            Row {
                anchors.top: parent.top
                anchors.topMargin: 7
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9
                Repeater {
                    model: Math.max(6, Math.floor((bd.width - 60) / 17))
                    Rectangle {
                        width: 3; height: 3; radius: 1.5
                        color: chrome.linenA(0.3)
                    }
                }
            }
            // a tiny podstakannik parked in the bottom-right of the tray
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 16
                anchors.bottomMargin: 12
                width: 16; height: 16
                opacity: 0.55
                Rectangle { x: 3; y: 0; width: 10; height: 13; color: "transparent"; border.width: 1; border.color: chrome.linenA(0.7) }
                Rectangle { x: 2; y: 7; width: 12; height: 7; color: "transparent"; border.width: 1; border.color: chrome.teaA(0.9) }
                Rectangle { x: 5; y: 4; width: 6; height: 8; color: chrome.teaA(0.55) }
                Rectangle { x: 14; y: 8; width: 3; height: 5; color: "transparent"; border.width: 1; border.color: chrome.teaA(0.8) }
            }
        }
    }

    // ── header: lamp + name + tea-glass EQ + distance ───────────────────────
    readonly property Component header: Component {
        Column {
            spacing: 12

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Rectangle {   // the reading lamp, breathing softly while the tray is out
                        id: lampPip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: chrome.pal.amber
                        SequentialAnimation on opacity {
                            running: chrome.popup.open
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 1500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THE OVERNIGHT BERTH"
                        font.family: chrome.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 4
                        color: chrome.pal.amber
                    }

                    // three little tea glasses, filling with the music
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        opacity: (chrome.audio.ready && !chrome.audio.silent) ? 1 : 0.3
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Repeater {
                            model: [
                                { band: "bass", col: chrome.pal.amber },
                                { band: "mid",  col: chrome.pal.neon },
                                { band: "high", col: chrome.pal.cyan }
                            ]
                            delegate: Item {
                                required property var modelData
                                readonly property real lvl: Math.min(1, chrome.audio[modelData.band] || 0)
                                width: 8; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {   // glass
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.width: 1
                                    border.color: chrome.linenA(0.4)
                                }
                                Rectangle {   // the tea
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 4
                                    height: Math.max(1, (parent.height - 3) * parent.lvl)
                                    color: modelData.col
                                    Behavior on height { NumberAnimation { duration: 120 } }
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
                        text: "CAR 7 · NIGHT SERVICE"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        color: chrome.pal.cyan
                        opacity: 0.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DIST " + chrome.popup.uptimeText.replace("up ", "").toUpperCase()
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.woodA(1.0)
                    }
                }
            }

            // perforation rule across the tray
            Item {
                id: headRule
                width: parent.width
                height: 3
                Row {
                    spacing: 8
                    Repeater {
                        model: Math.max(3, Math.floor((headRule.width + 8) / 11))
                        Rectangle {
                            width: 3; height: 3; radius: 1.5
                            color: chrome.teaA(0.4)
                        }
                    }
                }
            }
        }
    }

    // ── footer: the line + the send-off ─────────────────────────────────────
    readonly property Component footer: Component {
        Column {
            spacing: 12

            Item {
                id: footRule
                width: parent.width
                height: 3
                Row {
                    spacing: 8
                    Repeater {
                        model: Math.max(3, Math.floor((footRule.width + 8) / 11))
                        Rectangle {
                            width: 3; height: 3; radius: 1.5
                            color: chrome.woodA(0.6)
                        }
                    }
                }
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
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.neon
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "OFF THE LINE"
                            : (chrome.popup.connName || "ON THE LINE")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 9
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.linenA(0.75)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SLEEP WELL"
                        font.family: chrome.mono
                        font.pixelSize: 8
                        font.letterSpacing: 3
                        color: chrome.teaA(0.6)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "☾"
                        font.pixelSize: 10
                        color: chrome.pal.cyan
                        opacity: 0.8
                    }
                }
            }
        }
    }

    // ── overlay: now and then a lamp passes across the tray ────────────────
    readonly property Component overlay: Component {
        Item {
            id: ovl
            clip: true
            Rectangle {
                id: passing
                property real t: -1
                visible: t >= 0
                width: ovl.width * 0.4
                height: ovl.height * 1.6
                y: -ovl.height * 0.3
                x: -width + (ovl.width + width * 2) * Math.max(0, t)
                rotation: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.07) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                running: chrome.popup.open
                loops: Animation.Infinite
                PropertyAction { target: passing; property: "t"; value: 0 }
                NumberAnimation { target: passing; property: "t"; from: 0; to: 1; duration: 2000; easing.type: Easing.InOutSine }
                PropertyAction { target: passing; property: "t"; value: -1 }
                PauseAnimation { duration: 7000 }
            }
        }
    }
}
