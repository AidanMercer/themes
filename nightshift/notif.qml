import QtQuick
import "windows.js" as W

// nightshift: chrome for notification cards and the Super+I history drawer.
// A notification is a light going on in a window that was dark — so each card
// carries a narrow column of rooms down its left edge, and the top room lights
// sodium (or beacon, when it's urgent) while the card is up. The shell keeps
// the daemon, stacking, text and actions. Invisible Item root.
Item {
    id: chrome

    // injected by the notification layer (setSource initial property)
    required property var pal

    readonly property string sans: "Noto Sans"
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function slateA(a)  { return Qt.rgba(pal.dim.r, pal.dim.g, pal.dim.b, a) }
    function inkA(a)    { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // ── the card ────────────────────────────────────────────────────────────
    // glass — a card lands over whatever's on screen, so it keeps a little more
    // body than the desktop surfaces do (the layer is frosted in hyprland.conf)
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.62)
    readonly property color cardBorder: hazeA(0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3
    readonly property bool cardSpine: false     // the room column replaces it

    readonly property Component backdrop: Component {
        Item {
            id: bd
            property var note: null             // injected after load

            readonly property color hue: !bd.note ? chrome.pal.neon
                : bd.note.urgency === 2 ? chrome.pal.magenta
                : bd.note.accentCol ? bd.note.accentCol : chrome.pal.neon

            // the column of rooms down the left edge: the top one is the light
            // that just came on, the rest are the neighbours, mostly dark
            Facade {
                id: col
                x: 9
                y: 10
                cols: 2
                rows: Math.max(3, Math.floor(((bd.note ? bd.note.height : 60) - 20) / 11))
                cell: 4
                gap: 3
                lit: bd.hue
                dark: chrome.pal.dim
                darkAlpha: 0.32
                flicker: false
                spread: 260
                plan: {
                    const r = Math.max(3, Math.floor(((bd.note ? bd.note.height : 60) - 20) / 11))
                    const p = W.blank(2, r)
                    p[0] = 1; p[1] = 1                       // the new light, up top
                    for (let i = 2; i < p.length; i++)       // a couple of neighbours
                        if (((i * 2654435761) % 89) / 89 < 0.16) p[i] = 1
                    return p
                }
            }

            // a hover sheen — the room brightens as you reach for it
            Rectangle {
                anchors.fill: parent
                color: chrome.sodiumA(bd.note && bd.note.hovered ? 0.05 : 0)
                Behavior on color { ColorAnimation { duration: 220 } }
            }
        }
    }

    // ── the history drawer (Super+I) ────────────────────────────────────────
    readonly property color panelBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.66)
    readonly property color panelBorder: hazeA(0.28)
    readonly property int panelBorderWidth: 1
    readonly property int panelRadius: 3
    readonly property string panelTitle: "night log"

    readonly property Component panelBackdrop: Component {
        Item {
            id: pb
            property var panel: null            // injected after load

            // the block across the street, seen from the drawer. It dims to
            // almost nothing while do-not-disturb is on — the lights are out.
            Facade {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -4
                anchors.bottomMargin: -4
                cols: Math.max(5, Math.floor(parent.width / 24))
                rows: Math.max(4, Math.floor(parent.height / 24))
                cell: 11
                gap: 6
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.14
                dim: pb.panel && pb.panel.dnd === true ? 0.08 : 0.28
                spread: 1200
                opacity: 0.6
                plan: {
                    const c = Math.max(5, Math.floor(parent.width / 24))
                    const r = Math.max(4, Math.floor(parent.height / 24))
                    const p = W.blank(c, r)
                    if (pb.panel && pb.panel.dnd === true) return p    // everyone asleep
                    for (let i = 0; i < p.length; i++)
                        if (((i * 2654435761) % 811) / 811 < 0.13) p[i] = 1
                    return p
                }
            }
        }
    }
}
