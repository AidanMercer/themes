import QtQuick

// sleeper: night-journal chrome for vellum. Writing in the berth after
// lights-out: while you TYPE the compartment holds perfectly still — only
// the reading lamp's pool sits over the page. When a rendered page is up
// (readingMode/pdfMode) the journey shows again: the city's green settles at
// the floor of the window, a lamp passes across as each page composes, and
// every little while another one drifts by outside. The reading gate is the
// house contract: nothing animates behind a text column being typed into.
Item {
    id: chrome

    required property var pal   // snapshot palette (neon/cyan/magenta/…)
    property var host: null     // vellum window — active, readingMode, pdfMode

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page   // the only thing that may animate

    function teaA(a)   { return Qt.rgba(pal.amber.r, pal.amber.g, pal.amber.b, a) }
    function greenA(a) { return Qt.rgba(pal.neon.r, pal.neon.g, pal.neon.b, a) }
    function linenA(a) { return Qt.rgba(pal.text.r, pal.text.g, pal.text.b, a) }

    // chassis: paper corners, warm edge
    readonly property color cardBorder: Qt.alpha(pal.amber, 0.4)
    readonly property int cardBorderWidth: 1
    readonly property int cardRadius: 8

    // everything lives in the BACKDROP — nothing ever crawls over the glyphs
    readonly property Component backdrop: Component {
        Item {
            id: bd

            // the reading lamp's pool, top right — always there, still
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                width: parent.width * 0.42
                height: parent.height * 0.30
                opacity: 0.55
                gradient: Gradient {
                    GradientStop { position: 0.0; color: chrome.teaA(0.09) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }

            // the city's green at the floor — only while a page is up
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.25
                opacity: chrome.page ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutSine } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: chrome.greenA(0.07) }
                }
            }

            // lamps passing outside while you read — parked while you write
            Rectangle {
                id: drifter
                property real t: -1
                visible: t >= 0
                width: bd.width * 0.3
                height: bd.height * 1.6
                y: -bd.height * 0.3
                x: -width + (bd.width + width * 2) * Math.max(0, t)
                rotation: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.06) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                running: chrome.stirring
                loops: Animation.Infinite
                PropertyAction { target: drifter; property: "t"; value: 0 }
                NumberAnimation { target: drifter; property: "t"; from: 0; to: 1; duration: 2800; easing.type: Easing.InOutSine }
                PropertyAction { target: drifter; property: "t"; value: -1 }
                PauseAnimation { duration: 9000 }
            }

            // the page turn: one brighter lamp crosses as the page composes
            Rectangle {
                id: turnLamp
                property real t: -1
                visible: t >= 0
                width: bd.width * 0.4
                height: bd.height * 1.6
                y: -bd.height * 0.3
                x: -width + (bd.width + width * 2) * Math.max(0, t)
                rotation: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: chrome.teaA(0.0) }
                    GradientStop { position: 0.5; color: chrome.teaA(0.12) }
                    GradientStop { position: 1.0; color: chrome.teaA(0.0) }
                }
            }
            SequentialAnimation {
                id: turnSweep
                NumberAnimation { target: turnLamp; property: "t"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine }
                PropertyAction { target: turnLamp; property: "t"; value: -1 }
            }
            // gate on `page`, NOT `stirring`, or alt-tabbing re-fires the flourish
            Connections {
                target: chrome
                function onPageChanged() { if (chrome.page) turnSweep.restart() }
            }
        }
    }
}
