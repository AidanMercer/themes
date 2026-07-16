import QtQuick

// fuel: the canopy at night behind the miller columns — a neon orange stripe
// burning along the bottom edge with icy fluorescent underglow, flickering like
// a tired tube while the window is awake — and re-striking cold, a one-shot
// ignition stutter, every time you pull up to a new directory.
Item {
    id: chrome

    required property var pal
    property var host: null

    readonly property bool awake: host ? host.active === true : false

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⛽ FUEL 24H"

    readonly property Component backdrop: Component {
        Item {
            // icy fluorescent haze rising off the ground, breathing like a tube hum
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.10) }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.awake
                    NumberAnimation { to: 0.7; duration: 5200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
                }
            }

            // frozen mist creeping over the ground while the pumps run
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("mist.frag.qsb")
                property real time: 0
                NumberAnimation on time {
                    from: 0; to: 3600; duration: 3600000
                    loops: Animation.Infinite
                    running: chrome.awake
                }
            }

            // the stripe + its bloom
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
                        GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.neon, 0.20) }
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2.5
                    radius: 1
                    color: Qt.alpha(chrome.pal.neon, 0.75)
                }
                // tube flicker — a couple of dips, then a long steady burn
                SequentialAnimation {
                    running: chrome.awake
                    loops: Animation.Infinite
                    onStopped: canopy.opacity = 1
                    PauseAnimation { duration: 7000 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.45; duration: 60 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 90 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 0.7; duration: 50 }
                    NumberAnimation { target: canopy; property: "opacity"; to: 1.0; duration: 140 }
                }
                // re-strike — pulling up to a new bay, the tube arcs cold: a
                // hard fluorescent stutter over the stripe, then it hands back
                // to the steady orange burn
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
                            GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.30) }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 2.5
                        radius: 1
                        color: Qt.alpha(chrome.pal.cyan, 0.95)
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
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onNavIdChanged() { if (chrome.awake) restrike.restart() }
                }
            }
        }
    }
}
