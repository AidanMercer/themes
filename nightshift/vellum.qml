import QtQuick
import "windows.js" as W

// nightshift: chrome for the vellum editor. Reading at this hour is the same
// as any other lit window — so the haze and the block sit BEHIND the panes
// (the text column has no background of its own, and glyphs stay crisp over a
// backdrop, not under an overlay).
//
// The reading gate is the whole discipline here: the page stirs while you read
// and holds dead still while you write, so nothing ever moves behind a line
// being typed into. A plain .py buffer therefore never animates at all.
Item {
    id: chrome

    // injected by vellum's engine (snapshot semantics — any change reloads)
    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page      // the only thing that may animate

    function hazeA(a)   { return Qt.rgba(pal.cyan.r, pal.cyan.g, pal.cyan.b, a) }
    function sodiumA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }

    // glass, not a wall — a shade heavier than the other apps because a text
    // column sits straight on it, still well under the old opaque frame
    readonly property color cardBg: Qt.rgba(pal.glass.r, pal.glass.g, pal.glass.b, 0.46)
    readonly property color cardBorder: hazeA(0.28)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 3

    // the page composing is the event — fired on `page`, NOT on `stirring`, or
    // alt-tabbing back to an open page would re-fire it every time
    property real warm: 0
    property int pageSeed: 0
    SequentialAnimation {
        id: surge
        running: false
        NumberAnimation { target: chrome; property: "warm"; to: 0.85; duration: 240; easing.type: Easing.OutQuad }
        NumberAnimation { target: chrome; property: "warm"; to: 0; duration: 1900; easing.type: Easing.InOutSine }
    }
    Connections {
        target: chrome
        function onPageChanged() {
            if (!chrome.page) return
            chrome.pageSeed++
            if (chrome.stirring) surge.restart()
        }
    }

    readonly property Component backdrop: Component {
        Item {
            id: bd

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("haze.frag.qsb")
                property real time: 0
                property real warm: chrome.warm
                property real density: 0.42          // quiet — there's reading going on
                property vector4d coolCol: Qt.vector4d(chrome.pal.cyan.r, chrome.pal.cyan.g,
                                                       chrome.pal.cyan.b, 1)
                property vector4d warmCol: Qt.vector4d(chrome.pal.neon.r, chrome.pal.neon.g,
                                                       chrome.pal.neon.b, 1)
                opacity: 0.28          // haze, not paint — the frame stays glass
                NumberAnimation on time {
                    running: chrome.stirring
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                }
            }

            // a low band of rooftops along the foot of the window — the city
            // you're not looking at while you read
            Facade {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -6
                height: 90
                cols: Math.max(10, Math.floor(parent.width / 26))
                rows: 4
                cell: 11
                gap: 7
                lit: chrome.pal.neon
                dark: chrome.pal.dim
                darkAlpha: 0.09
                dim: 0.20 + 0.28 * chrome.warm
                flicker: chrome.stirring
                spread: 1400
                opacity: 0.55
                plan: {
                    const c = Math.max(10, Math.floor(parent.width / 26))
                    const p = W.blank(c, 4)
                    const seed = (chrome.pageSeed + 1) * 4933
                    for (let i = 0; i < p.length; i++)
                        if ((((i + 1) * 2654435761 + seed) % 887) / 887 < 0.15) p[i] = 1
                    return p
                }
            }
        }
    }
}
