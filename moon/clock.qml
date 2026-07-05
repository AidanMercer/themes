import QtQuick
import Quickshell

// Cyberpunk: Edgerunners desktop clock for the "moon" wallpaper.
//
// Loaded by the quickshell themeclock module while this wallpaper is showing.
// Self-contained (it lives outside the repo's module tree, so no shared Theme).
//
// It's a cyberware HUD pinned to the middle-left: David's neon yellow time with
// a chromatic-aberration glitch (cyan/magenta ghosts that split on a burst and
// settle back), CRT scanlines, a roaming scan beam, HUD corner brackets, and a
// left status rail. No CJK font on this box, so the flavor stays latin/symbol.
Item {
    id: root
    anchors.fill: parent

    // injected by the loader (setSource initial property)
    required property var pal
    readonly property color neon:    pal.neon   // edgerunners yellow
    readonly property color cyan:    pal.cyan
    readonly property color magenta: pal.magenta
    readonly property color dim:     pal.dim    // burnt-out yellow trace
    readonly property string mono:   "Noto Sans Mono"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ---- glitch driver ------------------------------------------------------
    // Baseline chromatic split is a calm ~1.5px; a burst slams it wide then eases
    // back while a slice band kicks sideways. Bursts fire on a re-randomised gap.
    property real gx: 1.5
    property bool slicing: false

    Timer {
        id: glitchTimer
        interval: 2600
        repeat: true
        running: true
        onTriggered: {
            glitchBurst.restart()
            interval = 1500 + Math.floor(Math.random() * 3600)
        }
    }

    SequentialAnimation {
        id: glitchBurst
        PropertyAction { target: root; property: "slicing"; value: true }
        NumberAnimation { target: root; property: "gx"; to: 7; duration: 50; easing.type: Easing.OutQuad }
        PropertyAction { target: root; property: "slicing"; value: false }
        NumberAnimation { target: root; property: "gx"; to: 1.5; duration: 260; easing.type: Easing.OutQuad }
    }

    // boot-in: slide/fade in from the left while the header types out, then one
    // glitch burst as the "signal locks"
    property real bootT: 0
    SequentialAnimation {
        running: true
        NumberAnimation { target: root; property: "bootT"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        ScriptAction { script: glitchBurst.restart() }
    }

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Math.round(root.height * 0.04)
        anchors.leftMargin: Math.round(root.width * 0.022) - Math.round(18 * (1 - root.bootT))
        opacity: root.bootT
        spacing: 22

        scale: pal.uiScale
        transformOrigin: Item.Left

        // ---- left status rail ----------------------------------------------
        // A thin neon spine with cyber-deck blocks: solid yellow run, a magenta
        // chunk, a cyan tick. Pure scenery, echoes the bar's accent language.
        Item {
            width: 12
            height: timeCol.height
            anchors.verticalCenter: parent.verticalCenter

            Rectangle { x: 5; width: 2; height: parent.height; color: root.dim }
            Rectangle { x: 4; width: 4; height: parent.height * 0.46; color: root.neon }
            Rectangle { x: 4; y: parent.height * 0.52; width: 4; height: parent.height * 0.22; color: root.magenta }
            Rectangle { x: 3; y: parent.height * 0.80; width: 6; height: 6; color: root.cyan }
            Rectangle { x: 0; y: 0;  width: 12; height: 3; color: root.neon }
            Rectangle { x: 0; y: parent.height - 3; width: 12; height: 3; color: root.neon }
        }

        // ---- the HUD block -------------------------------------------------
        Item {
            id: frame
            width: timeCol.width + 40
            height: timeCol.height + 28
            anchors.verticalCenter: parent.verticalCenter

            // dark HUD readout backing so neon reads over the bright Earth.
            // Fades to the right; left edge gets a thin cyan rule.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.62) }
                    GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
            Rectangle {
                x: -6; width: 2
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.margins: -6
                color: root.cyan
                opacity: 0.5
            }

            // HUD corner brackets — four L's hugging the block.
            Repeater {
                model: [
                    { ax: "left",  ay: "top" },
                    { ax: "right", ay: "top" },
                    { ax: "left",  ay: "bottom" },
                    { ax: "right", ay: "bottom" }
                ]
                Item {
                    width: 20; height: 20
                    x: modelData.ax === "left" ? 0 : frame.width - width
                    y: modelData.ay === "top"  ? 0 : frame.height - height
                    Rectangle {
                        width: parent.width; height: 2; color: root.cyan
                        anchors.left: parent.left
                        y: modelData.ay === "top" ? 0 : parent.height - height
                    }
                    Rectangle {
                        width: 2; height: parent.height; color: root.cyan
                        anchors.top: parent.top
                        x: modelData.ax === "left" ? 0 : parent.width - width
                    }
                }
            }

            Column {
                id: timeCol
                anchors.centerIn: parent
                spacing: 4

                // header: corp tag + live blink
                Row {
                    spacing: 8
                    Rectangle {
                        width: 9; height: 9; color: root.neon
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.15; duration: 0 }
                            PauseAnimation { duration: 620 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 620 }
                        }
                    }
                    Text {
                        readonly property string full: "NIGHT CITY ▸ NET.RUNNER"
                        // types out over the first ~2/3 of the boot-in
                        text: full.substring(0, Math.round(Math.min(1, root.bootT * 1.5) * full.length))
                        color: root.cyan
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        font.letterSpacing: 5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // the time — chromatic-aberration stack
                Item {
                    width: timeText.width
                    height: timeText.height

                    Text {
                        x: root.gx; y: 0
                        text: timeText.text
                        font: timeText.font
                        color: root.magenta
                        opacity: 0.9
                    }
                    Text {
                        x: -root.gx; y: 0
                        text: timeText.text
                        font: timeText.font
                        color: root.cyan
                        opacity: 0.9
                    }
                    Text {
                        id: timeText
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: root.neon
                        font.family: root.mono
                        font.weight: Font.Black
                        font.pixelSize: 104
                        font.letterSpacing: 2
                    }

                    // glitch slice: a thin band of the time kicked sideways
                    Item {
                        x: 14
                        y: timeText.height * 0.42
                        width: timeText.width
                        height: timeText.height * 0.16
                        clip: true
                        visible: root.slicing
                        Text {
                            y: -timeText.height * 0.42
                            text: timeText.text
                            font: timeText.font
                            color: root.cyan
                        }
                    }

                    // seconds, riding the top-right like a HUD readout
                    Text {
                        anchors.left: parent.right
                        anchors.leftMargin: 6
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        text: Qt.formatDateTime(clock.date, "ss")
                        color: root.magenta
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 22
                        font.letterSpacing: 2
                    }
                }

                // neon divider with a roaming notch
                Item {
                    width: timeText.width
                    height: 3
                    Rectangle { anchors.fill: parent; color: root.dim }
                    Rectangle {
                        width: 46; height: 3; color: root.neon
                        x: 0
                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            NumberAnimation { to: timeText.width - 46; duration: 3200; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 3200; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // date
                Text {
                    text: Qt.formatDateTime(clock.date, "ddd  dd.MM.yyyy").toUpperCase()
                    color: root.cyan
                    font.family: root.mono
                    font.weight: Font.Medium
                    font.pixelSize: 18
                    font.letterSpacing: 7
                }

                // status footer + cursor
                Row {
                    spacing: 7
                    Text {
                        text: "// NETRUNNER ONLINE"
                        color: root.dim
                        font.family: root.mono
                        font.weight: Font.Bold
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 8; height: 13; color: root.neon
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 0 }
                            PauseAnimation { duration: 440 }
                            NumberAnimation { to: 1; duration: 0 }
                            PauseAnimation { duration: 440 }
                        }
                    }
                }
            }

            // CRT scanlines over the whole block
            Canvas {
                anchors.fill: parent
                opacity: 0.20
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#000000"
                    ctx.lineWidth = 1
                    for (let y = 0; y < height; y += 3) {
                        ctx.beginPath()
                        ctx.moveTo(0, y + 0.5)
                        ctx.lineTo(width, y + 0.5)
                        ctx.stroke()
                    }
                }
            }

            // roaming scan beam
            Rectangle {
                width: frame.width
                height: 2
                color: root.cyan
                opacity: 0.25
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { to: frame.height; duration: 4200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 0 }
                    PauseAnimation { duration: 1600 }
                }
            }
        }
    }
}
