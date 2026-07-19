import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Mpris

// road8: the bar IS the road. A strip of night asphalt along the top edge —
// the overpass above the desktop — with the lane's dashed center line
// running through it, and through the
// middle of the strip the dashes become the workspaces. The little 8-bit car
// (taillights red, headlights amber) parks on the active dash and DRIVES to
// the next one when you switch, in chunky 3px steps, flipping to face its
// direction of travel, coughing two exhaust pixels as it goes. Apps on a
// workspace hang above its dash like signs beside the road.
//   left   — the dash radio: FM plate, hard-blinking play pip, title, and a
//            progress line built from tiny road dashes
//   right  — CHECK engine lamp (hover = the dash diagnostic panel), a pixel
//            signal mast, a pixel battery, the time in house 5×7 pixel
//            digits, and the ignition button for the control popup
// Panels are pixel-cut (stepped corners) — no rounded anything on this road.
// Self-contained: hyprland via Quickshell.Hyprland, /proc + nmcli.
Item {
    id: root
    anchors.fill: parent

    // injected by the bar wrapper after load (Loader.onLoaded)
    property var barScreen: null
    // injected by the loader (setSource initial property)
    required property var pal
    // loader pushes true while the session is locked — parks the pollers
    property bool occluded: false

    readonly property color amber: pal.neon
    readonly property color starlight: pal.cyan
    readonly property color tail: pal.magenta
    readonly property color warn: pal.amber
    readonly property color slate: pal.dim
    readonly property color ink: pal.text
    readonly property color glass: pal.glass
    readonly property string mono: pal.fontMono
    function amberA(a) { return Qt.rgba(amber.r, amber.g, amber.b, a) }
    function inkA(a)   { return Qt.rgba(ink.r, ink.g, ink.b, a) }
    function slateA(a) { return Qt.rgba(slate.r, slate.g, slate.b, a) }
    function glassA(a) { return Qt.rgba(glass.r, glass.g, glass.b, a) }

    readonly property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor
    readonly property real roadY: height * 0.66   // where the paint sits on the asphalt

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // boot-in: the center line paints itself across, then everything drops
    // down from the screen edge in 2px steps
    property real bootT: 0
    NumberAnimation on bootT { running: true; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
    readonly property real bootDrop: Math.max(0, (bootT - 0.4) / 0.6)
    readonly property int bootLift: -Math.round(6 * (1 - bootDrop) / 2) * 2

    // ── house pixel font (digits + colon) — same 5×7 map as the clock ──────
    readonly property var pixmap: ({
        "0": ["01110","10001","10011","10101","11001","10001","01110"],
        "1": ["00100","01100","00100","00100","00100","00100","01110"],
        "2": ["01110","10001","00001","00010","00100","01000","11111"],
        "3": ["11111","00010","00100","00010","00001","10001","01110"],
        "4": ["00010","00110","01010","10010","11111","00010","00010"],
        "5": ["11111","10000","11110","00001","00001","10001","01110"],
        "6": ["00110","01000","10000","11110","10001","10001","01110"],
        "7": ["11111","00001","00010","00100","01000","01000","01000"],
        "8": ["01110","10001","10001","01110","10001","10001","01110"],
        "9": ["01110","10001","10001","01111","00001","00010","01100"],
        ":": ["000","000","010","000","010","000","000"],
        " ": ["00000","00000","00000","00000","00000","00000","00000"]
    })
    component PixelGlyph: Canvas {
        id: g
        property string ch: " "
        property real cell: 2.6
        property color face: root.amber
        readonly property var m: root.pixmap[ch] || root.pixmap[" "]
        width: (m[0].length + 0.4) * cell
        height: (m.length + 0.4) * cell
        onChChanged: requestPaint()
        onFaceChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const c = cell, gap = Math.max(0.6, c * 0.16)
            ctx.fillStyle = String(Qt.rgba(0, 0, 0, 0.45))
            for (let r = 0; r < m.length; r++)
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c + c * 0.3, r * c + c * 0.3, c - gap, c - gap)
            ctx.fillStyle = String(face)
            for (let r = 0; r < m.length; r++)
                for (let k = 0; k < m[r].length; k++)
                    if (m[r].charAt(k) === "1")
                        ctx.fillRect(k * c, r * c, c - gap, c - gap)
        }
    }

    // pixel-cut panel: a rectangle with one-step chamfered corners
    component PixelPanel: Canvas {
        id: pp
        property color fill: root.glassA(0.82)
        property color stroke: root.slateA(0.75)
        property real cut: 3
        onFillChanged: requestPaint()
        onStrokeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (width <= 0 || height <= 0) return
            const w = width, h = height, s = cut
            ctx.beginPath()
            ctx.moveTo(s, 0.5)
            ctx.lineTo(w - s, 0.5)
            ctx.lineTo(w - s, s); ctx.lineTo(w - 0.5, s)
            ctx.lineTo(w - 0.5, h - s); ctx.lineTo(w - s, h - s)
            ctx.lineTo(w - s, h - 0.5); ctx.lineTo(s, h - 0.5)
            ctx.lineTo(s, h - s); ctx.lineTo(0.5, h - s)
            ctx.lineTo(0.5, s); ctx.lineTo(s, s)
            ctx.closePath()
            ctx.fillStyle = String(fill)
            ctx.fill()
            ctx.strokeStyle = String(stroke)
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    // ── the asphalt ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.glassA(0.55)
    }
    Rectangle {   // the shoulder line along the bottom edge, against the desktop
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: root.slateA(0.5)
    }

    // the dashed center line, skipping the workspace zone (those dashes are
    // the workspaces). reveals left→right on boot, dash by dash.
    Repeater {
        model: Math.max(0, Math.floor(root.width / 38))
        Rectangle {
            required property int index
            readonly property real cx: index * 38 + 12
            x: cx
            y: root.roadY - 1.5
            width: 16; height: 3
            color: root.amberA(0.22)
            visible: (cx / root.width) < root.bootT
                     && (cx + 16 < wsCluster.x - 8 || cx > wsCluster.x + wsCluster.width + 8)
        }
    }

    // ── center: the workspaces are the center line ──────────────────────────
    Item {
        id: wsCluster
        readonly property int wsCount: 10
        readonly property int activeWsId: root.monitor?.activeWorkspace?.id ?? 1
        readonly property int pageBase: activeWsId >= 1
            ? Math.floor((activeWsId - 1) / wsCount) * wsCount + 1
            : 1
        readonly property real slotW: 34
        readonly property int activeSlot: activeWsId - pageBase
        width: wsCount * slotW
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootDrop

        function iconForWindows(wins) {
            let best = null, bestFh = Infinity
            for (const w of wins) {
                const cls = w.lastIpcObject?.class ?? ""
                if (!cls) continue
                const fh = w.lastIpcObject?.focusHistoryID ?? Infinity
                if (fh < bestFh) { best = w; bestFh = fh }
            }
            if (!best) return Quickshell.iconPath("application-x-executable")
            const entry = DesktopEntries.heuristicLookup(best.lastIpcObject.class)
            const name = (entry && entry.icon) ? entry.icon : best.lastIpcObject.class.toLowerCase()
            return Quickshell.iconPath(name, "application-x-executable")
        }

        Repeater {
            model: wsCluster.wsCount
            delegate: Item {
                id: slot
                required property int index
                readonly property int wsId: wsCluster.pageBase + index
                readonly property bool isActive: wsCluster.activeWsId === wsId
                readonly property var windowsHere: Hyprland.toplevels.values
                    .filter(t => (t.workspace?.id ?? -1) === wsId)
                readonly property bool isOccupied: windowsHere.length > 0

                x: index * wsCluster.slotW
                width: wsCluster.slotW
                height: parent.height

                // the dash this workspace owns
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.roadY - 2
                    width: 20; height: 4
                    color: slot.isActive ? root.amber
                         : slot.isOccupied ? root.amberA(0.6)
                         : root.slateA(0.65)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                // the app riding this stretch, a sign beside the road
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 5 + root.bootLift
                    width: 13; height: 13
                    visible: slot.isOccupied && !slot.isActive
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                    opacity: 0.55
                }
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 3 + root.bootLift
                    width: 15; height: 15
                    visible: slot.isOccupied && slot.isActive
                    source: slot.isOccupied ? wsCluster.iconForWindows(slot.windowsHere) : ""
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${slot.wsId}`)
                }
            }
        }

        // ── the car ─────────────────────────────────────────────────────────
        Item {
            id: car
            width: 22
            height: 10
            y: root.roadY - 12

            // target follows the active dash; the drawn x lands on a 3px grid
            property real tx: wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - width / 2
            Behavior on tx { NumberAnimation { duration: 340; easing.type: Easing.InOutQuad } }
            x: Math.round(tx / 3) * 3

            readonly property bool driving: Math.abs(tx - (wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - width / 2)) > 1.5
            property int facing: 1

            transform: Scale {
                origin.x: car.width / 2
                xScale: car.facing
            }

            // chassis + cabin
            Rectangle { x: 1; y: 4; width: 20; height: 4; color: root.slateA(1) }
            Rectangle { x: 6; y: 1; width: 10; height: 3; color: root.slateA(1) }
            Rectangle { x: 8; y: 2; width: 6; height: 2; color: Qt.rgba(root.starlight.r, root.starlight.g, root.starlight.b, 0.55) }
            // wheels
            Rectangle { x: 4; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
            Rectangle { x: 15; y: 8; width: 3; height: 2; color: Qt.rgba(0, 0, 0, 0.9) }
            // taillight (rear) / headlight (front) — brighter while driving
            Rectangle { x: 0; y: 4; width: 2; height: 3; color: root.tail; opacity: car.driving ? 1 : 0.75 }
            Rectangle { x: 20; y: 4; width: 2; height: 3; color: root.amber; opacity: car.driving ? 1 : 0.6 }
            // exhaust pixels, only while rolling
            Rectangle { x: -4; y: 6; width: 2; height: 2; color: root.inkA(0.35); visible: car.driving }
            Rectangle { x: -8; y: 5; width: 2; height: 2; color: root.inkA(0.18); visible: car.driving }

            Connections {
                target: wsCluster
                function onActiveSlotChanged() {
                    const nx = wsCluster.activeSlot * wsCluster.slotW + wsCluster.slotW / 2 - car.width / 2
                    car.facing = nx >= car.tx ? 1 : -1
                    car.tx = nx
                }
            }
        }
    }

    // keep workspace occupancy fresh — toplevels are empty until refreshed
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "activewindowv2":
                Hyprland.refreshToplevels()
            }
        }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    // ── left: the dash radio ────────────────────────────────────────────────
    Item {
        id: media
        readonly property var player: {
            const ps = Mpris.players.values
            if (ps.length === 0) return null
            return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0]
        }
        readonly property bool active: player !== null
        readonly property bool playing: active && player.playbackState === MprisPlaybackState.Playing

        visible: active
        x: 12
        y: Math.round((parent.height - height) / 2) + root.bootLift
        width: radioRow.width + 24
        height: 28
        opacity: root.bootDrop

        PixelPanel { anchors.fill: parent }

        Row {
            id: radioRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "FM"
                color: root.amber
                font.family: root.mono
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1
            }
            // the play pip: a hard-blinking pixel while the radio's on
            Rectangle {
                id: pip
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 5
                property bool tick: true
                color: media.playing ? root.amber : root.slateA(0.9)
                opacity: media.playing ? (tick ? 1 : 0.25) : 0.5
                Timer {
                    interval: 700; repeat: true
                    running: media.playing && !root.occluded
                    onTriggered: pip.tick = !pip.tick
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
                elide: Text.ElideRight
                text: {
                    if (!media.active) return ""
                    const t = media.player.trackTitle || "—"
                    const a = media.player.trackArtist
                    return a ? t + " · " + a : t
                }
                textFormat: Text.PlainText
                color: root.inkA(0.85)
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        // track progress: the road ahead, dash by dash
        property real progress: 0
        Timer {
            interval: 1000; repeat: true
            running: media.playing && !root.occluded
            triggeredOnStart: true
            onTriggered: {
                const p = media.player
                media.progress = (p && p.length > 0 && p.position >= 0)
                    ? Math.min(1, p.position / p.length) : 0
            }
        }
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottomMargin: 3
            spacing: 3
            Repeater {
                model: 14
                Rectangle {
                    required property int index
                    width: 6; height: 2
                    color: index < Math.round(media.progress * 14) ? root.amberA(0.9) : root.slateA(0.5)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying()
            onWheel: (w) => {
                if (!media.active) return
                if (w.modifiers & Qt.ShiftModifier) {
                    Quickshell.execDetached(["qs", "ipc", "call", "lyricOffset",
                        w.angleDelta.y > 0 ? "earlier" : "later"])
                    return
                }
                if (w.angleDelta.y > 0 && media.player.canGoNext) media.player.next()
                else if (w.angleDelta.y < 0 && media.player.canGoPrevious) media.player.previous()
            }
        }
    }

    // ── right: dashboard tell-tales ─────────────────────────────────────────
    property bool online: false
    property string connType: ""
    property int batteryPercent: -1
    property bool batteryCharging: false
    property bool hasBattery: false

    Timer {
        interval: 10000; running: !root.occluded; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; batProc.running = true }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -vi ':loopback\\|:bridge\\|:tun' | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line) { root.online = false; root.connType = ""; return }
                const t = line.slice(line.lastIndexOf(":") + 1)
                root.connType = t.indexOf("wireless") >= 0 ? "wifi" : t.indexOf("ethernet") >= 0 ? "eth" : "net"
                root.online = true
            }
        }
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -e \"$b/capacity\" ] && { cat \"$b/capacity\" \"$b/status\"; break; }; done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const cap = parseInt(lines[0])
                if (lines[0] === "" || isNaN(cap)) { root.hasBattery = false; return }
                root.hasBattery = true
                root.batteryPercent = cap
                root.batteryCharging = (lines[1] || "").trim() === "Charging"
            }
        }
    }

    // hover flag shared with sysinfo.qml — the CHECK lamp writes "1"/"0" here
    readonly property string sysFlagPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR")
        return ((rt && String(rt).length) ? String(rt) : "/tmp") + "/theme-sysinfo-hover"
    }
    FileView { id: sysFlag; path: root.sysFlagPath; atomicWrites: false; printErrors: false }

    Row {
        id: rightRow
        spacing: 8
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: root.bootLift
        height: parent.height
        opacity: root.bootDrop

        // CHECK — the engine lamp; hover it to pull the diagnostic panel up.
        // gone while the readout is toggled off in settings.
        PixelPanel {
            visible: root.pal.sysinfoOn !== false
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 24
            stroke: checkMa.containsMouse ? root.amberA(0.9) : root.slateA(0.75)
            // a tiny pixel engine block
            Item {
                anchors.centerIn: parent
                width: 14; height: 9
                readonly property color lamp: checkMa.containsMouse ? root.amber : root.amberA(0.45)
                Rectangle { x: 2; y: 3; width: 10; height: 5; color: parent.lamp }
                Rectangle { x: 4; y: 1; width: 5; height: 2; color: parent.lamp }
                Rectangle { x: 0; y: 4; width: 2; height: 3; color: parent.lamp }
                Rectangle { x: 12; y: 4; width: 2; height: 2; color: parent.lamp }
            }
            MouseArea {
                id: checkMa
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: sysFlag.setText(containsMouse ? "1" : "0")
            }
        }

        // signal mast: four rising pixel bars
        PixelPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 24
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property int lit: root.online ? (root.connType === "eth" ? 4 : 3) : 0
                        width: 3
                        height: 4 + index * 3
                        anchors.bottom: parent.bottom
                        color: index < lit ? root.amber : root.slateA(0.7)
                    }
                }
            }
            // offline: a red pixel at the mast's foot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 4
                width: 4; height: 4
                color: root.tail
                visible: !root.online
            }
        }

        // pixel battery (laptops only)
        PixelPanel {
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter
            width: 38; height: 24
            Item {
                anchors.centerIn: parent
                width: 22; height: 10
                Rectangle {   // shell
                    x: 0; y: 0; width: 19; height: 10
                    color: "transparent"
                    border.width: 1
                    border.color: root.slateA(1)
                }
                Rectangle { x: 19; y: 3; width: 2; height: 4; color: root.slateA(1) }   // tip
                Row {   // charge cells
                    x: 2; y: 2
                    spacing: 1
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: 2.6; height: 6
                            visible: root.batteryPercent >= 0 && index < Math.ceil(root.batteryPercent / 20)
                            color: root.batteryCharging ? root.starlight
                                 : root.batteryPercent <= 15 ? root.tail
                                 : root.batteryPercent <= 30 ? root.warn
                                 : root.amber
                        }
                    }
                }
                Rectangle {   // charging bolt pixel above the shell
                    x: 8; y: -3; width: 3; height: 3
                    color: root.starlight
                    visible: root.batteryCharging
                }
            }
        }

        // the time, in house pixels
        PixelPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: timeRow.width + 16
            height: 26
            Row {
                id: timeRow
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 5
                    PixelGlyph {
                        required property int index
                        ch: Qt.formatDateTime(clock.date, "HH:mm").charAt(index)
                        cell: 2.4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ignition — the control popup
        PixelPanel {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 24
            stroke: ignMa.containsMouse ? root.amberA(0.9) : root.slateA(0.75)
            // a pixel key: round bow + toothed blade
            Item {
                anchors.centerIn: parent
                width: 12; height: 12
                readonly property color kc: ignMa.containsMouse ? root.amber : root.inkA(0.7)
                Rectangle { x: 3; y: 0; width: 6; height: 6; color: "transparent"; border.width: 2; border.color: parent.kc }
                Rectangle { x: 5; y: 6; width: 2; height: 6; color: parent.kc }
                Rectangle { x: 7; y: 8; width: 2; height: 2; color: parent.kc }
                Rectangle { x: 7; y: 11; width: 2; height: 1; color: parent.kc }
            }
            MouseArea {
                id: ignMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "controlPopup", "toggle"])
            }
        }
    }
}
