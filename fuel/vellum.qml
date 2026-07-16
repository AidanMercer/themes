import QtQuick

// fuel: the canopy at night behind the page. The stripe burns steady while
// you're working — the tired tube only starts flickering, and the frozen mist
// only creeps over the ground, once you sit back and read. Each page that
// composes re-strikes the tube: a cold one-shot ignition stutter, then the
// steady burn.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false
    readonly property bool page: host ? (host.readingMode === true || host.pdfMode === true) : false
    readonly property bool stirring: awake && page

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1

    readonly property Component backdrop: Component {
        Item {
            // icy fluorescent haze rising off the ground, breathing like a tube hum
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.09) }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.stirring
                    NumberAnimation { to: 0.7; duration: 5200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
                }
            }

            // frozen mist creeping over the ground while the page is up
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("mist.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.stirring
                }
            }

            // the stripe + its bloom — lit whenever the window is
            Item {
                id: canopy
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.bottomMargin: 2
                height: 30
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 26
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.18) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2.5
                    radius: 1
                    color: Qt.alpha(chrome.pal.neon, 0.70)
                }
                // tube flicker — a couple of dips, then a long steady burn. Never
                // while you're typing; onStopped puts the tube back to full so a
                // mid-flicker stop can't leave it dim.
                SequentialAnimation {
                    running: chrome.stirring
                    loops: Animation.Infinite
                    onStopped: canopy.opacity = 1
                    PauseAnimation { duration: 7000 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.45; duration: 60 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 90 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.7; duration: 50 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 140 }
                }
                // re-strike — the page comes up and the tube arcs cold: a hard
                // fluorescent stutter over the stripe, then it hands back to
                // the steady orange burn
                Item {
                    id: strike
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 12
                    opacity: 0
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 12
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.28) }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 2.5
                        radius: 1
                        color: Qt.alpha(chrome.pal.cyan, 0.90)
                    }
                }
                SequentialAnimation {
                    id: restrike
                    PropertyAction { target: strike; property: "opacity"; value: 1 }
                    PauseAnimation { duration: 45 }
                    PropertyAction { target: strike; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: strike; property: "opacity"; value: 0.85 }
                    PauseAnimation { duration: 55 }
                    PropertyAction { target: strike; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 110 }
                    PropertyAction { target: strike; property: "opacity"; value: 1 }
                    NumberAnimation { target: strike; property: "opacity"; to: 0; duration: 340; easing.type: Easing.OutQuad }
                }
                Connections {
                    target: chrome
                    function onPageChanged() { if (chrome.stirring) restrike.restart() }
                }
            }
        }
    }
}
