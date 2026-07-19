import QtQuick

// downpour: reading against the glass. While a page is up the pane behind
// the text keeps its condensation — a sparse bead field breathing at the
// window's pace — and the moment you start typing everything holds still
// (the reading gate: stirring = awake && page, verbatim from the docs).
// When a page composes, a fingertip gleam wipes once across the fog —
// downpour's page turn — and is gone. Backdrop only; the glyphs stay crisp.
Item {
    id: chrome

    required property var pal   // snapshot palette (pane-light/skin/warmth…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    readonly property color paneLight: pal.neon
    function paneA(a) { return Qt.rgba(paneLight.r, paneLight.g, paneLight.b, a) }
    function inkA(a)  { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // chassis: a soft breath-mark frame
    readonly property color cardBorder: inkA(0.12)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 18

    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the pane's condensation — stirs only while a page is being read
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("fog.frag.qsb")
                property real time: 0
                property real density: 0.09
                property color tint: chrome.paneLight
                opacity: 0.55
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // a breath pooling faintly at the top of the pane while reading
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 90
                opacity: chrome.page ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 700 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.inkA(0.045) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ── the page turn: one fingertip gleam wipes across the fog ─────
            Rectangle {
                id: gleam
                property real t: -1
                visible: t >= 0
                width: 60
                height: bd.height * 1.4
                rotation: 16
                x: -width + (bd.width + width * 2) * Math.max(0, t)
                y: -bd.height * 0.2
                opacity: 0.5 * Math.sin(Math.max(0, t) * Math.PI)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.inkA(0.0) }
                    GradientStop { position: 0.5; color: chrome.inkA(0.10) }
                    GradientStop { position: 1.0; color: chrome.inkA(0.0) }
                }
                SequentialAnimation {
                    id: gleamAnim
                    NumberAnimation { target: gleam; property: "t"; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutSine }
                    PropertyAction { target: gleam; property: "t"; value: -1 }
                }
            }
            Connections {
                target: chrome
                // gate on page, not stirring — alt-tab must not re-fire it
                function onPageChanged() { if (chrome.page) gleamAnim.restart() }
            }
        }
    }
}
