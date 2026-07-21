import QtQuick

// encore: chrome for the Super+M control menu. The popup is the desk's
// clipped-up sheet for tonight: a stage-black capsule card with the teal
// edge-strip foot, a cue lamp ticking the count in the header next to a
// three-lamp monitor EQ (bass is the crowd's magenta, mid the diva's teal,
// high the lacquer blue — law 4, side by side, never blended), uptime on
// the right, connection status in the footer. Invisible Item root; the
// shell mounts the Components around its shared tabs.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    // the backdrop draws the whole card
    readonly property color cardBg: "transparent"
    readonly property color cardBorder: "transparent"
    readonly property int cardBorderWidth: 0
    readonly property int cardRadius: 16

    readonly property string mono: pal.fontMono

    // ── backdrop: the sheet itself ──────────────────────────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Qt.rgba(chrome.pal.glass.r, chrome.pal.glass.g, chrome.pal.glass.b, 0.95)
                border.width: 1
                border.color: Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.4)
            }
            // the teal edge-strip foot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 44
                height: 2
                radius: 1
                color: Qt.rgba(chrome.pal.neon.r, chrome.pal.neon.g, chrome.pal.neon.b, 0.5)
            }
            // the clip at the top of the sheet — two small lamp screws
            Rectangle {
                x: parent.width * 0.5 - 26; y: 7
                width: 6; height: 6; radius: 3
                color: Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.9)
            }
            Rectangle {
                x: parent.width * 0.5 + 20; y: 7
                width: 6; height: 6; radius: 3
                color: Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.9)
            }
        }
    }

    // ── header: cue lamp + monitor EQ, uptime on the right ──────────────────
    readonly property Component header: Component {
        Column {
            spacing: 14

            Item {
                width: parent.width
                height: 16

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // the cue lamp — hard tick on the internal count
                    Rectangle {
                        id: cueLamp
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        property bool tick: true
                        color: tick ? chrome.pal.neon
                                    : Qt.rgba(chrome.pal.dim.r, chrome.pal.dim.g, chrome.pal.dim.b, 0.8)
                        Timer {
                            interval: 500; repeat: true
                            running: chrome.popup.open
                            onTriggered: cueLamp.tick = !cueLamp.tick
                        }
                        onVisibleChanged: if (!visible) tick = true
                    }
                    // monitor EQ: three lamps off the shell's cava — dances
                    // while anything plays, parks dim at silence (law 3)
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
                                radius: 1.5
                                anchors.bottom: parent.bottom
                                color: modelData.col
                                // whole-pixel steps — an LED ladder, not a needle
                                height: 2 + 2 * Math.round(5 * Math.min(1, chrome.audio[modelData.band] || 0))
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
                    color: chrome.pal.dim
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

    // ── footer: connection status ───────────────────────────────────────────
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
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.neon
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chrome.popup.connType === "none" ? "offline"
                            : (chrome.popup.connName || "online")
                        textFormat: Text.PlainText
                        font.family: chrome.mono
                        font.pixelSize: 10
                        color: chrome.popup.connType === "none" ? chrome.pal.magenta : chrome.pal.cyan
                    }
                }
            }
        }
    }
}
