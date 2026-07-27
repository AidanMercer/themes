import QtQuick
import "windows.js" as W

// nightshift: chrome for the Super+M control menu. The shell keeps its shared
// tabs; this file makes the card the inside of one of those lit rooms — a dark
// navy interior with the block's own facade showing faintly behind the
// controls, a sodium sill light along the head, and the audio bus running as a
// strip of rooms that light with the mix. Invisible Item root.
Item {
    id: chrome

    // injected by ControlPopup (setSource initial properties)
    required property var pal      // ThemePalette — neon/cyan/magenta/amber/dim
    required property var popup    // the popup root — open, uptimeText, connType, connName
    required property var audio    // AudioBus — bass/mid/high, silent, ready

    readonly property string mono: pal.fontMono
    readonly property string sans: "Noto Sans"
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function inkA(a)    { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // the room's window is glass, not a wall — Hyprland frosts this surface
    // (layerrule blur, quickshell-control-popup), so the card can stay this
    // open and still read
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.58)
    readonly property color cardBorder: hazeA(0.30)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3

    // ── backdrop: the facade, seen from inside the room ─────────────────────
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // a sparse block of rooms, most of them dark — structure, not data
            Facade {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -6
                anchors.bottomMargin: -6
                cols: Math.max(6, Math.floor(parent.width / 26))
                rows: Math.max(4, Math.floor(parent.height / 26))
                cell: 12
                gap: 7
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                // barely there: the controls have to read over this, so the
                // block is a suggestion of a facade, not a texture
                darkAlpha: 0.09
                dim: 0.26
                spread: 900
                opacity: 0.45
                plan: {
                    const c = Math.max(6, Math.floor(parent.width / 26))
                    const r = Math.max(4, Math.floor(parent.height / 26))
                    const p = W.blank(c, r)
                    // a fixed scatter — the neighbours who happen to be up
                    for (let i = 0; i < p.length; i++)
                        if (((i * 2654435761) % 997) / 997 < 0.14) p[i] = 1
                    return p
                }
            }

            // the sill light along the head of the card
            Rectangle {
                width: parent.width
                height: 1
                y: 0
                color: chrome.sodiumA(0.30)
            }
        }
    }

    // ── header: the sill — wordmark, the mix as rooms ───────────────────────
    readonly property Component header: Component {
        Item {
            id: hd
            implicitHeight: 40

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6
                    color: chrome.pal.neon
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "still up"
                    color: chrome.inkA(0.95)
                    font.family: chrome.sans
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.letterSpacing: 2.4
                }
            }

            // the mix, as a floor of rooms lighting with the sound
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                opacity: chrome.audio && chrome.audio.ready && !chrome.audio.silent ? 1 : 0.30
                Behavior on opacity { NumberAnimation { duration: 320 } }

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property real lvl: !chrome.audio ? 0
                            : index === 0 ? chrome.audio.bass
                            : index === 1 ? chrome.audio.mid : chrome.audio.high
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7
                        color: chrome.pal.neon
                        opacity: 0.22 + 0.78 * Math.max(0, Math.min(1, lvl))
                    }
                }
            }
        }
    }

    // ── footer: how long the lights have been on, and the wire ──────────────
    readonly property Component footer: Component {
        Item {
            implicitHeight: 30

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                // uptimeText already reads "up 1h 29m" — don't say it twice
                text: chrome.popup.uptimeText || "—"
                color: chrome.inkA(0.72)
                font.family: chrome.mono
                font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const t = chrome.popup.connType || ""
                    const n = chrome.popup.connName || ""
                    return t === "" ? "offline" : (n !== "" ? n : t)
                }
                textFormat: Text.PlainText
                color: (chrome.popup.connType || "") === ""
                    ? chrome.pal.magenta : chrome.inkA(0.72)
                font.family: chrome.mono
                font.pixelSize: 11
            }
        }
    }
}
