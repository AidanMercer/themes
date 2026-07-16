import QtQuick

// fuel: the pump island reads the machine's vitals. the canopy stripe burns
// under the gauges and the chrome is wired to the load — frozen mist thickens
// as the cpu works, the icy haze brightens, and past 70% the tired tube starts
// buzzing dirty. a re-sort rolls the price board: one cyan shimmer down the
// stripe. a kill is a tube dying hard — the stripe goes black, tail-lights
// flare past, then the cold re-strike hands back to the steady burn.
Item {
    id: chrome

    required property var pal
    property var host: null   // pulse window — active, load, memLoad, sortId, killPulse

    readonly property bool awake: host ? host.active === true : false
    readonly property real load: host && host.load !== undefined ? host.load : 0

    readonly property color cardBorder: Qt.alpha(pal.neon, 0.28)
    readonly property int cardBorderWidth: 1

    readonly property string wordmark: "⛽ TANK LEVELS"

    readonly property Component backdrop: Component {
        Item {
            // icy fluorescent haze breathing like a tube hum — brighter as the
            // machine works
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.cyan, 0.08 + chrome.load * 0.07) }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: chrome.awake
                    NumberAnimation { to: 0.7; duration: 5200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 5200; easing.type: Easing.InOutSine }
                }
            }

            // frozen mist creeping over the ground — it thickens as the cpu
            // climbs, like the pumps running hot into cold air
            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("mist.frag.qsb")
                property real time: 0
                opacity: 0.55 + chrome.load * 0.45
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

                // dirty buzz — past 70% load the tube stops burning clean: a
                // pale cold stutter rides the stripe until the machine settles
                Rectangle {
                    id: buzz
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 2.5
                    radius: 1
                    color: Qt.alpha(chrome.pal.cyan, 0.9)
                    opacity: 0
                }
                SequentialAnimation {
                    running: chrome.awake && chrome.load > 0.7
                    loops: Animation.Infinite
                    onStopped: buzz.opacity = 0
                    NumberAnimation { target: buzz; property: "opacity"; to: 0.22; duration: 70 }
                    NumberAnimation { target: buzz; property: "opacity"; to: 0.05; duration: 110 }
                    NumberAnimation { target: buzz; property: "opacity"; to: 0.18; duration: 60 }
                    NumberAnimation { target: buzz; property: "opacity"; to: 0.0; duration: 480 }
                    PauseAnimation { duration: 900 }
                }

                // price-board roll (sort) — the numbers flip and a cyan shimmer
                // sweeps once down the stripe
                Rectangle {
                    id: sweep
                    anchors.bottom: parent.bottom
                    width: 90; height: 2.5
                    radius: 1
                    x: -90
                    color: Qt.alpha(chrome.pal.cyan, 0.85)
                    opacity: 0
                }
                SequentialAnimation {
                    id: priceRoll
                    PropertyAction { target: sweep; property: "opacity"; value: 0.75 }
                    NumberAnimation { target: sweep; property: "x"; from: -90; to: canopy.width; duration: 430; easing.type: Easing.OutCubic }
                    PropertyAction { target: sweep; property: "opacity"; value: 0 }
                }

                // the kill — a tube dying hard. the stripe blacks out, the
                // wedge car's tail-lights flare past, a cold stutter, then the
                // re-strike brings the orange burn back.
                Rectangle {
                    id: dead
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 30
                    color: Qt.alpha(chrome.pal.glass, 0.92)
                    opacity: 0
                }
                Item {
                    id: tail
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 26
                    opacity: 0
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.alpha(chrome.pal.magenta, 0.30) }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        height: 2.5
                        radius: 1
                        color: Qt.alpha(chrome.pal.magenta, 0.9)
                    }
                }
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
                    id: tubeDeath
                    PropertyAction { target: dead; property: "opacity"; value: 1 }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: tail; property: "opacity"; value: 0.85 }
                    NumberAnimation { target: tail; property: "opacity"; to: 0; duration: 240; easing.type: Easing.OutQuad }
                    PauseAnimation { duration: 60 }
                    PropertyAction { target: strike; property: "opacity"; value: 1 }
                    PauseAnimation { duration: 45 }
                    PropertyAction { target: strike; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: strike; property: "opacity"; value: 0.9 }
                    PauseAnimation { duration: 50 }
                    PropertyAction { target: strike; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 60 }
                    PropertyAction { target: dead; property: "opacity"; value: 0 }
                    PropertyAction { target: strike; property: "opacity"; value: 1 }
                    NumberAnimation { target: strike; property: "opacity"; to: 0; duration: 240; easing.type: Easing.OutQuad }
                }

                Connections {
                    target: chrome.host
                    enabled: chrome.host !== null
                    function onSortIdChanged() { if (chrome.awake) priceRoll.restart() }
                    function onKillPulseChanged() { if (chrome.awake) tubeDeath.restart() }
                }
            }
        }
    }
}
